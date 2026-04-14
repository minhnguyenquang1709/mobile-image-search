import 'package:mobile_image_search/src/shared/domain/model/media.dart';

abstract class IGalleryRepository {
  /// permission to access gallery
  Future<bool> requestGalleryAccess();

  /// Read device's gallery
  ///
  /// Return a list of [MediaAsset] with pagination support
  Future<List<MediaAsset>> readGallery({required int page, required int limit});

  /// Read specific album from device's gallery, with pagination support
  Future<List<MediaAsset>> readAlbum({
    required String albumId,
    required int page,
    required int limit,
  });

  // write operations
  Future<bool> createAlbum(String albumName);
  Future<bool> deleteAlbum(String albumId);
  Future<bool> moveMediaToAlbum(List<String> assetIds, String targetAlbumId);
  Future<bool> moveMediaToTrash(List<String> assetIds);

  /// Get metadata of all images and videos
  Future<List<MediaAsset>> getAllMetadata();
}
