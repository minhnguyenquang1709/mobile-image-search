import 'dart:io';

import 'package:mobile_image_search/shared/domain/media.dart';
import 'package:mobile_image_search/shared/domain/interface/image_interface.dart';
import 'package:photo_manager/photo_manager.dart';

abstract class IGalleryRepository {
  Future<List<Media>> readGallery({required int page, int limit});
  Future<bool> requestGalleryAccess();
  Future<bool> deleteImage(String imageId);
  Future<File> getImageFile(String assetId);
  Future<void> getImageMetadata(String assetId);
  Future<List<IMediaMetadata>> getAllMetadata();

  // album management
  Future<List<Media>> readAlbum({
    required String albumId,
    required int page,
    int limit,
  });
  Future<List<AssetPathEntity>> getAlbumList();
  Future<void> createAlbum(String albumName);
  Future<void> deleteAlbum(String albumId);
  Future<void> moveImagesToAlbum(List<String> assetIds, String targetAlbumId);
}
