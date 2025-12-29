import 'package:mobile_image_search/service/indexing_queue_service.dart';
import 'package:mobile_image_search/service/photo_gallery_service.dart';
import 'package:mobile_image_search/service/vector_store_service.dart';
import 'package:mobile_image_search/utils/logger.dart';
import 'package:photo_manager/photo_manager.dart';

class AppRepository {
  final PhotoGalleryService _photoGalleryService;
  final VectorStoreService _vectorStoreService;
  final IndexingQueueService _indexingQueueService;

  AppRepository({
    required PhotoGalleryService photoGalleryService,
    required VectorStoreService vectorStoreService,
    required IndexingQueueService indexingQueueService,
  }) : _photoGalleryService = photoGalleryService,
       _vectorStoreService = vectorStoreService,
       _indexingQueueService = indexingQueueService;

  get isPermissionGranted => _photoGalleryService.isGalleryAccessGranted;

  List<AssetEntity> get assets => _photoGalleryService.assets;

  Future<void> init() async {
    try {
      await this._photoGalleryService.init();
      await this._vectorStoreService.init();
    } catch (e) {
      debugLogger.printLog('Error initializing AppRepository: $e');
      rethrow;
    }
  }

  /// request list of photos
  ///
  /// check with vector store for existing indexed photos
  ///
  /// create indexing jobs for the unindexed photos
  Future<void> syncGallery() async {
    await _photoGalleryService.syncGallery();
  }

  /// search images by query string
  Future<void> searchImages(String query) async {
    query = query.trim();
  }
}
