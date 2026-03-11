import 'dart:io';

import 'package:mobile_image_search/shared/domain/image_model.dart';

abstract class IGalleryRepository {
  Future<List<Image>> readGallery({required int page, int limit});
  Future<bool> requestGalleryAccess();
  Future<bool> deleteImage(String imageId);
  Future<File> getImageFile(String assetId);
  Future<void> getImageMetadata(String assetId);
}
