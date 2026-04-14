import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/feature/gallery/data/gallery_repository.dart';
import 'package:mobile_image_search/src/shared/data/repository/background_worker_repository.dart';
import 'package:mobile_image_search/src/shared/domain/interface/gallery_repository_interface.dart';
import 'package:mobile_image_search/src/feature/indexing/domain/indexing_progress.dart';
import 'package:mobile_image_search/src/shared/domain/interface/background_worker_interface.dart';
import 'package:mobile_image_search/src/shared/application/inference_worker_repository.dart';
import 'package:mobile_image_search/src/utils/logger.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_repository.dart';
import 'package:mobile_image_search/src/feature/indexing/domain/store_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/media.dart';

class IndexingService {
  final Queue<MediaAsset> taskQueue = Queue<MediaAsset>();

  /// Queue for pending embeddings to save - deferred from main indexing loop
  final Queue<Map<String, dynamic>> _saveQueue = Queue();

  final StreamController<IndexingProgress> _progressController =
      StreamController<IndexingProgress>.broadcast();
  Stream<IndexingProgress> get progressStream => _progressController.stream;

  int _total = 0;
  int _processed = 0;

  final IBackgroundWorkerRepository _workerRepo;

  final Logger _logger = loggers[LoggerName.indexingService]!;

  final IStoreRepository _storeRepo;
  final IGalleryRepository _galleryRepo;

  IndexingService({
    required IStoreRepository storeRepository,
    required IGalleryRepository galleryRepository,
    required IBackgroundWorkerRepository workerRepo,
  }) : _galleryRepo = galleryRepository,
       _storeRepo = storeRepository,
       _workerRepo = workerRepo;

  bool _isProcessing = false;
  bool _isSaving = false; // Prevent concurrent saves

  /// Copy model files from assets to file system to allow worker isolate to read
  ///
  /// Check for necessary gallery change and update indexing on app startup
  ///
  /// Change status and display to user
  Future<void> initialize() async {
    try {
      // check for necessary gallery change and update indexing on app startup
      _syncIndexingInBackground();
    } catch (e, _) {
      rethrow;
    }
  }

  Future<void> _syncIndexingInBackground() async {
    final List<MediaAsset> pendingAssets = [];
    final List<String> deletePendingAssetIds = [];

    _logger.printLog('Checking for gallery changes on startup...');
    final List<MediaAsset> allGalleryMedia = await _galleryRepo
        .getAllMetadata();
    final Map<String, MediaAsset> allIndexedMedia = await _storeRepo
        .getAllIndexedMediaMetadata();

    // int count = 0;
    for (final media in allGalleryMedia) {
      // count++;

      // if (count % 500 == 0) {
      //   await Future.delayed(Duration.zero);
      // }

      final indexedMedia = allIndexedMedia[media.assetId];
      if (indexedMedia == null) {
        // new asset, need indexing
        pendingAssets.add(media);
      } else {
        // existing asset, check for modification
        if (media.modifiedDateTime.isAfter(indexedMedia.modifiedDateTime)) {
          // asset modified, need re-indexing
          pendingAssets.add(media);
        }
      }
      allIndexedMedia.remove(media.assetId);
    }

    // remaining items in allIndexedMedia are deleted from gallery, need to remove from index
    deletePendingAssetIds.addAll(allIndexedMedia.keys);

    enQueue(pendingAssets);
    processNextTask();
    _storeRepo.deleteImageEmbeddings(deletePendingAssetIds);

    _logger.printLog(
      'Gallery change check completed. ${pendingAssets.length} assets pending indexing, ${deletePendingAssetIds.length} assets pending deletion from index.',
    );
  }

  void enQueue(List<MediaAsset> media) {
    _total += media.length;
    taskQueue.addAll(media);
    _logger.printLog('Enqueued indexing task for image $media');
    _notifyProgress();
  }

  void _notifyProgress() {
    _progressController.add(
      IndexingProgress(
        total: _total,
        processed: _processed,
        isIndexing: taskQueue.isNotEmpty || _isProcessing,
      ),
    );
  }

  void processNextTask() {
    if (taskQueue.isEmpty || _isProcessing) {
      return;
    }

    _isProcessing = true;
    final media = taskQueue.removeFirst();

    // use public API to ensure proper taskId tracking
    _logger.printLog('Start processing indexing task for image $media');
    // _workerRepo
    //     .indexImage(media)
    //     .then(
    //       (result) {
    //         if (result.embedding != null) {
    //           // Queue the save instead of doing it synchronously - prevents UI jank
    //           _saveQueue.add({
    //             'media': result.media,
    //             'embedding': result.embedding!,
    //           });
    //           _logger.printLog(
    //             'Indexed asset ${result.media.assetId} (queued for save)',
    //           );
    //           _processSaveQueue(); // Start async save process
    //         } else {
    //           // error handling
    //           _logger.printLog(
    //             "Error indexing asset ${result.media.assetId}: ${result.errorMessage}",
    //           );
    //         }

    //         _processed++;
    //         _notifyProgress();

    //         _isProcessing = false;
    //         processNextTask();
    //       },
    //       onError: (e) {
    //         _logger.printLog("Error processing task for ${media.assetId}: $e");
    //         _processed++;
    //         _notifyProgress();

    //         _isProcessing = false;
    //         processNextTask();
    //       },
    //     );
  }

  /// Process queued embeddings in background without blocking main indexing loop
  void _processSaveQueue() {
    if (_saveQueue.isEmpty || _isSaving) {
      return;
    }

    _isSaving = true;
    final item = _saveQueue.removeFirst();

    _storeRepo
        .saveImageEmbedding(
          item['media'] as MediaAsset,
          item['embedding'] as Float32List,
        )
        .then((_) {
          _isSaving = false;
          // Process next queued save
          if (_saveQueue.isNotEmpty) {
            _processSaveQueue();
          }
        })
        .catchError((e) {
          _logger.printLog('Error saving embedding: $e');
          _isSaving = false;
          // Continue with next save even on error
          if (_saveQueue.isNotEmpty) {
            _processSaveQueue();
          }
        });
  }
}

final indexingServiceProvider = FutureProvider((ref) async {
  final storeRepository = await ref.watch(objectBoxStoreRepoProvider.future);
  final galleryRepository = ref.watch(galleryRepositoryProvider);
  final worker = await ref.watch(backgroundWorkerRepoProvider.future);

  final service = IndexingService(
    storeRepository: storeRepository,
    galleryRepository: galleryRepository,
    workerRepo: worker,
  );
  await service.initialize();
  return service;
});
