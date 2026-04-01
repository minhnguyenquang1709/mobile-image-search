import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/feature/gallery/data/gallery_repository.dart';
import 'package:mobile_image_search/src/feature/gallery/domain/gallery_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_metadata.dart';
import 'package:mobile_image_search/src/shared/domain/model/media.dart';

class GalleryService {
  final IGalleryRepository _galleryRepository;

  GalleryService(this._galleryRepository);

  Future<List<Media>> readGallery({required int page, int limit = 100}) async {
    return await _galleryRepository.readGallery(page: page, limit: limit);
  }

  Future<bool> requestGalleryAccess() async {
    return await _galleryRepository.requestGalleryAccess();
  }

  /// delete image from gallery and remove from vector store
  Future<bool> deleteImage(String imageId) async {
    return await _galleryRepository.deleteImage(imageId);
  }

  Future<void> getImageMetadata(String assetId) async {
    await _galleryRepository.getImageMetadata(assetId);
  }

  Future<List<Media>> getAllMetadata() async {
    return await _galleryRepository.getAllMetadata();
  }
}

final galleryServiceProvider = Provider((ref) {
  final repository = ref.watch(galleryRepositoryProvider);
  return GalleryService(repository);
});
