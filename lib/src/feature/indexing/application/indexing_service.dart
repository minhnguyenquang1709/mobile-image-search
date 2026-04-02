import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/feature/gallery/data/gallery_repository.dart';
import 'package:mobile_image_search/src/feature/gallery/domain/gallery_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/interface/background_worker_interface.dart';
import 'package:mobile_image_search/src/shared/application/inference_worker_repository.dart';
import 'package:mobile_image_search/src/utils/logger.dart';
import 'package:mobile_image_search/src/feature/indexing/domain/indexing_model.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_repository.dart';
import 'package:mobile_image_search/src/feature/indexing/domain/store_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/media.dart';

class IndexingProgress {
  final int total;
  final int processed;
  IndexingProgress({required this.total, required this.processed});

  double get progress => total == 0 ? 0 : processed / total;
}

class IndexingService {
  final Queue<IndexingTask> taskQueue = Queue<IndexingTask>();

  final StreamController<IndexingProgress> _progressController =
      StreamController<IndexingProgress>.broadcast();
  Stream<IndexingProgress> get progressStream => _progressController.stream;

  int _total = 0;
  int _processed = 0;

  final IInferenceWorkerRepository _workerRepo;

  final Logger _logger = loggers[LoggerName.indexingService]!;

  final IStoreRepository _storeRepo;
  final IGalleryRepository _galleryRepo;

  IndexingService({
    required IStoreRepository storeRepository,
    required IGalleryRepository galleryRepository,
    required IInferenceWorkerRepository workerRepo,
  }) : _galleryRepo = galleryRepository,
       _storeRepo = storeRepository,
       _workerRepo = workerRepo;

  bool _isProcessing = false;

  /// Copy model files from assets to file system to allow worker isolate to read
  ///
  /// Check for necessary gallery change and update indexing on app startup
  Future<void> initialize() async {
    try {
      _workerRepo.onMessage.listen((message) {
        handleWorkerResult(message);
      });

      // check for necessary gallery change and update indexing on app startup
      _syncIndexingInBackground();
    } catch (e, _) {
      rethrow;
    }
  }

  Future<void> _syncIndexingInBackground() async {
    final List<Media> pendingAssets = [];
    final List<String> deletePendingAssetIds = [];

    _logger.printLog('Checking for gallery changes on startup...');
    final allGalleryMedia = await _galleryRepo.getAllMetadata();
    final allIndexedMedia = await _storeRepo.getAllIndexedMediaMetadata();

    int count = 0;
    for (final media in allGalleryMedia) {
      count++;

      if (count % 500 == 0) {
        await Future.delayed(Duration.zero);
      }

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

  void enQueue(List<Media> media) {
    _total += media.length;
    taskQueue.addAll(media.map((item) => IndexingTask(media: item)));
    _logger.printLog('Enqueued indexing task for image $media');
    _notifyProgress();
  }

  void _notifyProgress() {
    _progressController.add(
      IndexingProgress(total: _total, processed: _processed),
    );
  }

  void processNextTask() {
    if (taskQueue.isEmpty || _isProcessing) {
      return;
    }

    _isProcessing = true;
    final task = taskQueue.removeFirst();

    // send task to worker
    _logger.printLog('Start processing indexing task for image ${task.media}');
    _workerRepo.workerSendPort?.send(task);
  }

  void handleWorkerResult(dynamic message) {
    if (message is IndexingResult) {
      if (message.embedding != null) {
        // save to db
        _storeRepo.saveImageEmbedding(message.media, message.embedding!);
        _logger.printLog(
          'Indexed asset ${message.media.assetId} successfully!',
        );
      } else {
        // error handling
        _logger.printLog(
          "Error indexing asset ${message.media.assetId}: ${message.errorMessage}",
        );
      }

      _processed++;
      _notifyProgress();

      _isProcessing = false;
      processNextTask();
    }
  }
}

final indexingServiceProvider = FutureProvider((ref) async {
  final storeRepository = await ref.watch(objectBoxStoreRepoProvider.future);
  final galleryRepository = ref.watch(galleryRepositoryProvider);
  final worker = await ref.watch(aiInferenceWorkerRepoProvider.future);

  final service = IndexingService(
    storeRepository: storeRepository,
    galleryRepository: galleryRepository,
    workerRepo: worker,
  );
  await service.initialize();
  return service;
});
