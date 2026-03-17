import 'dart:io';

import 'package:mobile_image_search/shared/domain/image_model.dart';
import 'package:mobile_image_search/shared/domain/interface/image_interface.dart';
import 'package:photo_manager/photo_manager.dart';

abstract class IGalleryRepository {
  Future<List<Image>> readGallery({required int page, int limit});
  Future<bool> requestGalleryAccess();
  Future<bool> deleteImage(String imageId);
  Future<File> getImageFile(String assetId);
  Future<void> getImageMetadata(String assetId);
  Future<List<IImageMetadata>> getAllMetadata();

  // album management
  Future<List<Image>> readAlbum({
    required String albumId,
    required int page,
    int limit,
  });
  Future<List<AssetPathEntity>> getAlbumList();
  Future<void> createAlbum(String albumName);
  Future<void> deleteAlbum(String albumId);
  Future<void> moveImagesToAlbum(List<String> assetIds, String targetAlbumId);
}
