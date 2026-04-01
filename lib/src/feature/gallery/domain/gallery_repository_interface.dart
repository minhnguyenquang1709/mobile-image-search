import 'dart:io';

import 'package:mobile_image_search/src/shared/domain/model/media.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_metadata.dart';
import 'package:photo_manager/photo_manager.dart';

abstract class IGalleryRepository {
  /// Read device's gallery
  ///
  /// Return a list of [Media] with pagination support
  Future<List<Media>> readGallery({required int page, int limit});

  /// Request permission to access gallery
  Future<bool> requestGalleryAccess();
  Future<bool> deleteImage(String imageId);
  Future<File> getImageFile(String assetId);
  Future<MediaMetadata> getImageMetadata(String assetId);

  /// Get metadata of all images and videos
  ///
  /// Not block the main thread
  Future<List<MediaMetadata>> getAllMetadata();

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
