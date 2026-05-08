import 'package:mobile_image_search/src/shared/domain/model/album.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

abstract class IAlbumRepository {
  Future<List<Album>> getAlbums();
  Future<List<MediaAsset>> getMediaAssetsInAlbum({
    required String albumId,
    int page,
    int limit,
  });
  Future<void> moveAssetsToAlbum(String albumId, List<String> assetIds);
}
