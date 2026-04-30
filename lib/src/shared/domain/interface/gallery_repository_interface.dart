import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:photo_manager/photo_manager.dart';

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
  Future<bool> createAlbum(String albumName, List<MediaAsset> mediaAssets);
  Future<bool> deleteAlbum(String albumId, {bool deleteMedia = false});
  Future<bool> moveMediaToAlbum(
    List<MediaAsset> mediaAssets,
    String targetAlbumId,
  );
  Future<bool> moveMediaToTrash(List<MediaAsset> mediaAssets);

  /// Get metadata of all images and videos
  Future<List<MediaAsset>> getAllMetadata();

  AssetEntity? getCachedEntity(String assetId);
}
