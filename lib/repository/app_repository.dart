// ignore_for_file: unnecessary_this

import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:mobile_image_search/model/indexing_job.dart';
import 'package:mobile_image_search/service/ai_inference_service.dart';
import 'package:mobile_image_search/service/indexing_queue_service.dart';
import 'package:mobile_image_search/service/photo_gallery_service.dart';
import 'package:mobile_image_search/service/store_service.dart';
import 'package:mobile_image_search/utils/logger.dart';
import 'package:photo_manager/photo_manager.dart';

class AppRepository {
  final PhotoGalleryService _photoGalleryService;
  final StoreService _vectorStoreService;
  final IndexingQueueService _indexingQueueService;
  final AiInferenceService _aiInferenceService;

  AppRepository({
    required PhotoGalleryService photoGalleryService,
    required StoreService vectorStoreService,
    required IndexingQueueService indexingQueueService,
    required AiInferenceService aiInferenceService,
  }) : _photoGalleryService = photoGalleryService,
       _vectorStoreService = vectorStoreService,
       _indexingQueueService = indexingQueueService,
       _aiInferenceService = aiInferenceService;

  final _logger = loggers[LoggerName.AppRepository]!;
  Logger get logger => _logger;
  bool _isIndexing = false;

  List<AssetEntity> get assets => _photoGalleryService.assets;
  List<AssetEntity> _pendingAssets = [];
  get isIndexing => _isIndexing;
  get isPermissionGranted => _photoGalleryService.isGalleryAccessGranted;
  ListQueue<IndexingJob> get indexingQueue => _indexingQueueService.queue;

  Future<Float32List> encodeImage(AssetEntity assetEntity) async {
    try {
      File? imageFile = await assetEntity.originFile;
      if (imageFile == null) {
        throw Exception('Unable to get file for asset ${assetEntity.id}');
      }
      return await _aiInferenceService.encodeImage(imageFile);
    } catch (e) {
      _logger.printLog('Error encoding image for asset ${assetEntity.id}: $e');
      rethrow;
    }
  }

  Future<Float32List> encodeText(String text) async {
    try {
      return await _aiInferenceService.encodeText(text);
    } catch (e) {
      _logger.printLog('Error encoding text "$text": $e');
      rethrow;
    }
  }

  Future<void> init() async {
    try {
      await this._photoGalleryService.init();
      await this._vectorStoreService.init();
      await this._aiInferenceService.init();
      // await syncGallery();
    } catch (e) {
      _logger.printLog('Error initializing: $e');
      rethrow;
    }
  }

  Future<void> requestGalleryAccess() async {
    try {
      await _photoGalleryService.requestGalleryAccess();
    } catch (e) {
      _logger.printLog('Error requesting gallery access: $e');
      rethrow;
    }
  }

  /// request list of photos
  ///
  /// check with vector store for existing indexed photos
  ///
  /// create indexing jobs for the unindexed photos
  Future<void> syncGallery() async {
    try {
      await _photoGalleryService.syncGallery();
      if (!isPermissionGranted) {
        _logger.printLog('Gallery access not granted');
        return;
      }

      if (assets.isEmpty) {
        _logger.printLog('No assets found in gallery');
        return;
      }

      // TODO: implement check for existing indexed photos in vector store
      _pendingAssets = assets; // placeholder for unindexed assets

      for (final asset in _pendingAssets) {
        final newIndexingJob = IndexingJob(
          assetId: asset.id,
          status: EIndexingStatus.pending,
          attemptCount: 0,
        );

        _indexingQueueService.enqueue(newIndexingJob);
      }

      _startProcessingQueue();
    } catch (e) {
      _logger.printLog('Error syncing gallery: $e');
      rethrow;
    }
  }

  /// indexing queue consumer loop
  /// constantly check the queue and process jobs
  Future<void> _startProcessingQueue() async {
    if (_isIndexing) {
      return;
    }

    _isIndexing = true;
    // TODO: notify listeners about indexing status change
    _logger.printLog("Starting background processing loop...");

    while (!_indexingQueueService.queue.isEmpty) {
      final job = _indexingQueueService.dequeue();
      if (job == null) break;

      try {
        final AssetEntity asset = _photoGalleryService.assets.firstWhere(
          (asset) => asset.id == job.assetId,
          orElse: () => throw Exception('Asset not found!'),
        );

        final file = await asset.file;
        if (file == null) {
          _logger.printLog("Unable to get file for asset ${asset.id}");
          throw Exception('Unable to get file for asset ${asset.id}');
        }

        final imageEmbedding = await _aiInferenceService.encodeImage(
          file,
        ); // await calls to C++, Dart will be free to render UI

        // TODO: save to vector store
      } catch (e) {
        _logger.printLog("Error processing job for asset ${job.assetId}: $e");
      }

      // notify UI about the progress, allow rendering (Dart is single-threaded)
      // TODO: implement notification to listeners
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _isIndexing = false;
    _logger.printLog("Processing queue finished.");

    // TODO: notify listeners about indexing status change
  }

  /// search images by query string
  Future<void> searchImages(String query) async {
    query = query.trim();
  }

  Future<void> dispose() async {
    await _aiInferenceService.dispose();
  }
}
