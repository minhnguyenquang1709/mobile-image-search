import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/feature/gallery/data/gallery_repository.dart';
import 'package:mobile_image_search/feature/gallery/domain/gallery_repository_interface.dart';
import 'package:mobile_image_search/shared/domain/image_model.dart';

class GalleryService {
  final IGalleryRepository _galleryRepository;

  GalleryService(this._galleryRepository);

  Future<List<Image>> readGallery({required int page, int limit = 100}) async {
    return await _galleryRepository.readGallery(page: page, limit: limit);
  }

  Future<bool> requestGalleryAccess() async {
    return await _galleryRepository.requestGalleryAccess();
  }

  /// delete image from gallery and remove from vector store
  Future<bool> deleteImage(String imageId) async {
    return await _galleryRepository.deleteImage(imageId);
  }
}

final galleryServiceProvider = Provider((ref) {
  final repository = ref.watch(galleryRepositoryProvider);
  return GalleryService(repository);
});

final galleryImagesProvider = FutureProvider<List<Image>>((ref) async {
  ref.onDispose(() {
    // add dispose logic
  });

  ref.keepAlive();
  final galleryService = ref.watch(galleryServiceProvider);
  final images = await galleryService.readGallery(page: 0, limit: 100);
  return images;
});
