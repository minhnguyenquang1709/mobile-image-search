import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/feature/gallery/data/gallery.repository.dart';
import 'package:mobile_image_search/feature/gallery/domain/interface.dart';
import 'package:mobile_image_search/shared/domain/image.model.dart';

class GalleryService {
  final IGalleryRepository _galleryRepository;

  GalleryService(this._galleryRepository);

  Future<List<Image>> readGallery() async {
    return await _galleryRepository.readGallery();
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

final galleryImagesProvider = FutureProvider.autoDispose<List<Image>>((ref) {
  final galleryService = ref.watch(galleryServiceProvider);
  return galleryService.readGallery();
});
