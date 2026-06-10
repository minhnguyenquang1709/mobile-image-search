import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:mobile_image_search/objectbox.g.dart';
import 'package:mobile_image_search/src/constants/config_constant.dart';
import 'package:mobile_image_search/src/feature/indexing/data/background_worker_data_source.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_image_embedding.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_repository.dart';
import 'package:mobile_image_search/src/shared/domain/interface/gallery_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/indexing_progress.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:photo_manager/photo_manager.dart';

/// Contains business rules related to indexing in background
///
/// Orchestrate the indexing process
///
/// - Iterate through gallery media asset list
///
/// - For each asset, send to background worker for embedding generation
///
/// - Save embedding result to database
class IndexingService {
  // Stream<IndexingProgress> get progressStream => _workerRepo.progressStream;
  // IndexingProgress get currentProgress => _workerRepo.currentIndexingProgress;

  final BackgroundWorkerDataSource _workerIsolateClient;

  final IGalleryRepository _galleryRepo;

  final ObjectBoxClient _objectBoxClient;

  IndexingProgress _currentIndexingProgress = IndexingProgress(
    total: 0,
    processed: 0,
    isIndexing: false,
  );

  final StreamController<IndexingProgress> _indexingProgressStreamController =
      StreamController.broadcast();

  Stream<IndexingProgress> get progressStream =>
      _indexingProgressStreamController.stream;

  IndexingProgress get currentProgress => _currentIndexingProgress;

  IndexingService({
    required BackgroundWorkerDataSource workerIsolateClient,
    required IGalleryRepository galleryRepository,
    required ObjectBoxClient objectBoxClient,
  }) : _galleryRepo = galleryRepository,
       _workerIsolateClient = workerIsolateClient,
       _objectBoxClient = objectBoxClient;

  bool get isIndexing => _currentIndexingProgress.isIndexing;

  Future<void> init() async {
    try {} catch (e, _) {
      rethrow;
    }
  }

  /// Start the indexing process for all gallery media assets
  ///
  /// - Diffing: compare gallery media list with indexed media list to determine new/modified/deleted assets
  ///
  /// - Iterate through new/modified assets,
  ///  send to background worker for embedding generation, and save result to database
  Future<void> indexGallery() async {
    if (isIndexing) {
      debugPrint(
        "[IndexingService] Indexing is already in progress, skipping new indexing request",
      );
      return;
    }
    debugPrint("[IndexingService] Starting gallery indexing process...");
    _currentIndexingProgress = _currentIndexingProgress.copyWith(
      isIndexing: true,
    );

    // diffing by metadata
    debugPrint("[IndexingService] Read all media from device...");
    final List<MediaAsset> galleryMediaList = await _galleryRepo
        .getAllMetadata();
    debugPrint("[IndexingService] Get all indexed media from database...");
    final imageEmbeddingBox = _objectBoxClient.store
        .box<ObjectBoxImageEmbedding>();
    final List<ObjectBoxImageEmbedding> indexedMediaList = imageEmbeddingBox
        .getAll();
    final Map<String, ObjectBoxImageEmbedding> indexedMediaMap = {
      for (var item in indexedMediaList) item.assetId: item,
    };

    final List<MediaAsset> assetsToIndex = [];

    debugPrint(
      "[IndexingService] Start diffing gallery media with indexed media...",
    );
    for (final media in galleryMediaList) {
      final indexedMedia = indexedMediaMap[media.assetId];
      if (indexedMedia == null) {
        // new asset, need indexing
        assetsToIndex.add(media);
      } else {
        // existing asset, check for modification
        if (media.modifiedDateTime.isAfter(indexedMedia.mediaModifiedAt)) {
          // asset modified, need re-indexing
          assetsToIndex.add(media);
        }
      }
      indexedMediaMap.remove(media.assetId);
    }

    final List<String> assetIdsToDelete = indexedMediaMap.keys.toList();
    debugPrint(
      "[IndexingService] Gallery diffing completed. ${assetsToIndex.length} assets to index, ${assetIdsToDelete.length} assets to delete from index.",
    );

    // delete removed assets from index
    bool isDeletionSuccess = false;
    if (assetIdsToDelete.isNotEmpty) {
      Query<ObjectBoxImageEmbedding> deleteQuery = imageEmbeddingBox
          .query(ObjectBoxImageEmbedding_.assetId.oneOf(assetIdsToDelete))
          .build();
      List<ObjectBoxImageEmbedding> embeddingsToDelete = deleteQuery.find();
      if (embeddingsToDelete.isNotEmpty) {
        int removedCount = await deleteQuery.removeAsync();
        isDeletionSuccess = removedCount == embeddingsToDelete.length;
      } else {
        isDeletionSuccess = true;
      }
    } else {
      isDeletionSuccess = true;
    }
    if (!isDeletionSuccess) {
      debugPrint(
        "[IndexingService] Warning: Not all removed assets were deleted from database",
      );
      throw Exception("Failed to delete removed assets from index");
    }

    // start indexing
    _currentIndexingProgress = _currentIndexingProgress.copyWith(
      total: assetsToIndex.length,
      processed: 0,
      isIndexing: true,
    );
    _indexingProgressStreamController.add(_currentIndexingProgress);

    final ThumbnailOption thumbnailOption = ThumbnailOption(
      size: ThumbnailSize.square(Model.specs.imageSize),
    );
    for (final media in assetsToIndex) {
      // get asset entity
      final AssetEntity? assetEntity = await AssetEntity.fromId(media.assetId);
      if (assetEntity == null) {
        debugPrint(
          "[IndexingService] Warning: AssetEntity not found for assetId ${media.assetId}, skipping indexing for this asset",
        );
        continue;
      }

      // read image thumbnail bytes
      Uint8List? thumbnailBytes = await assetEntity.thumbnailDataWithOption(
        thumbnailOption,
      );
      if (thumbnailBytes == null) {
        debugPrint(
          "[IndexingService] Warning: Failed to read thumbnail for assetId ${media.assetId}, skipping indexing for this asset",
        );
        continue;
      }

      try {
        // generate embedding
        final embedding = await _workerIsolateClient.encodeImage(
          media.assetId,
          media.title,
          thumbnailBytes,
        );

        // save to database
        final imageEmbedding = ObjectBoxImageEmbedding(
          assetId: media.assetId,
          title: media.title,
          mediaType: media.mediaType.index,
          duration: assetEntity.duration,
          embedding: embedding,
          mediaCreatedAt: media.createDateTime,
          mediaModifiedAt: media.modifiedDateTime,
        );
        await imageEmbeddingBox.putAsync(imageEmbedding);
        debugPrint(
          "[IndexingService] Saved embedding for ${media.assetId} to database",
        );

        _currentIndexingProgress = _currentIndexingProgress.copyWith(
          total: _currentIndexingProgress.total,
          processed: _currentIndexingProgress.processed + 1,
          isIndexing: true,
        );
        _indexingProgressStreamController.add(_currentIndexingProgress);
      } catch (e) {
        debugPrint(
          "[IndexingService] Error generating/saving embedding for ${media.assetId}: $e",
        );
      }
    }

    _currentIndexingProgress = IndexingProgress(
      total: _currentIndexingProgress.total,
      processed: _currentIndexingProgress.processed,
      isIndexing: false,
    );
    _indexingProgressStreamController.add(_currentIndexingProgress);
  }

  // Future<void> _syncIndexingInBackground() async {
  //   final List<MediaAsset> pendingAssets = [];
  //   final List<String> deletePendingAssetIds = [];

  //   // diffing
  //   // TODO: let background isolate handle the details, here just start the process
  //   // _logger.printLog('Checking for gallery changes on startup...');
  //   // final List<MediaAsset> allGalleryMedia = await _galleryRepo
  //   //     .getAllMetadata();
  //   // final Map<String, MediaAsset> allIndexedMedia = await _storeRepo
  //   //     .getAllIndexedMediaMetadata();

  //   // // int count = 0;
  //   // for (final media in allGalleryMedia) {
  //   //   // count++;

  //   //   // if (count % 500 == 0) {
  //   //   //   await Future.delayed(Duration.zero);
  //   //   // }

  //   //   final indexedMedia = allIndexedMedia[media.assetId];
  //   //   if (indexedMedia == null) {
  //   //     // new asset, need indexing
  //   //     pendingAssets.add(media);
  //   //   } else {
  //   //     // existing asset, check for modification
  //   //     if (media.modifiedDateTime.isAfter(indexedMedia.modifiedDateTime)) {
  //   //       // asset modified, need re-indexing
  //   //       pendingAssets.add(media);
  //   //     }
  //   //   }
  //   //   allIndexedMedia.remove(media.assetId);
  //   // }

  //   // // remaining items in allIndexedMedia are deleted from gallery, need to remove from index
  //   // deletePendingAssetIds.addAll(allIndexedMedia.keys);

  //   // enQueue(pendingAssets);
  //   // processNextTask();
  //   // _storeRepo.deleteImageEmbeddings(deletePendingAssetIds);

  //   // _logger.printLog(
  //   //   'Gallery change check completed. ${pendingAssets.length} assets pending indexing, ${deletePendingAssetIds.length} assets pending deletion from index.',
  //   // );

  //   _workerRepo.syncGallery(); // fire and forget
  // }

  // void enQueue(List<MediaAsset> media) {
  //   _total += media.length;
  //   taskQueue.addAll(media);
  //   _logger.printLog('Enqueued indexing task for image $media');
  //   _notifyProgress();
  // }

  // void _notifyProgress() {
  //   _progressController.add(
  //     IndexingProgress(
  //       total: _total,
  //       processed: _processed,
  //       isIndexing: taskQueue.isNotEmpty || _isProcessing,
  //     ),
  //   );
  // }

  // void processNextTask() {
  //   if (taskQueue.isEmpty || _isProcessing) {
  //     return;
  //   }

  //   _isProcessing = true;
  //   final media = taskQueue.removeFirst();

  //   // use public API to ensure proper taskId tracking
  //   _logger.printLog('Start processing indexing task for image $media');
  //   // _workerRepo
  //   //     .indexImage(media)
  //   //     .then(
  //   //       (result) {
  //   //         if (result.embedding != null) {
  //   //           // Queue the save instead of doing it synchronously - prevents UI jank
  //   //           _saveQueue.add({
  //   //             'media': result.media,
  //   //             'embedding': result.embedding!,
  //   //           });
  //   //           _logger.printLog(
  //   //             'Indexed asset ${result.media.assetId} (queued for save)',
  //   //           );
  //   //           _processSaveQueue(); // Start async save process
  //   //         } else {
  //   //           // error handling
  //   //           _logger.printLog(
  //   //             "Error indexing asset ${result.media.assetId}: ${result.errorMessage}",
  //   //           );
  //   //         }

  //   //         _processed++;
  //   //         _notifyProgress();

  //   //         _isProcessing = false;
  //   //         processNextTask();
  //   //       },
  //   //       onError: (e) {
  //   //         _logger.printLog("Error processing task for ${media.assetId}: $e");
  //   //         _processed++;
  //   //         _notifyProgress();

  //   //         _isProcessing = false;
  //   //         processNextTask();
  //   //       },
  //   //     );
  // }

  /// Process queued embeddings in background without blocking main indexing loop
  // void _processSaveQueue() {
  //   if (_saveQueue.isEmpty || _isSaving) {
  //     return;
  //   }

  //   _isSaving = true;
  //   final item = _saveQueue.removeFirst();

  //   _storeRepo
  //       .saveImageEmbedding(
  //         item['media'] as MediaAsset,
  //         item['embedding'] as Float32List,
  //       )
  //       .then((_) {
  //         _isSaving = false;
  //         // Process next queued save
  //         if (_saveQueue.isNotEmpty) {
  //           _processSaveQueue();
  //         }
  //       })
  //       .catchError((e) {
  //         _logger.printLog('Error saving embedding: $e');
  //         _isSaving = false;
  //         // Continue with next save even on error
  //         if (_saveQueue.isNotEmpty) {
  //           _processSaveQueue();
  //         }
  //       });
  // }
}

// final indexingServiceProvider = FutureProvider((ref) async {
//   final worker = await ref.watch(backgroundWorkerRepoProvider.future);

//   final service = IndexingService(workerRepo: worker);
//   await service.init();
//   return service;
// });
