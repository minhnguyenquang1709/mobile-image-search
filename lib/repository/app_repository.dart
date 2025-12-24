import 'package:mobile_image_search/service/indexing_queue_service.dart';
import 'package:mobile_image_search/service/photo_gallery_service.dart';
import 'package:mobile_image_search/service/vector_store_service.dart';

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

  Future<void> syncApp() async {}
}
