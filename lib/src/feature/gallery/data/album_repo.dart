import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/shared/domain/interface/album_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/album.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:mobile_image_search/src/utils/media_processing.dart';
import 'package:photo_manager/photo_manager.dart';

class AndroidAlbumRepo implements IAlbumRepository {
  /// uses photo_manager to get the list of albums, represented by [AssetPathEntity]
  @override
  Future<List<Album>> getAlbums() async {
    final FilterOptionGroup filterOptionGroup = FilterOptionGroup(
      orders: [const OrderOption(type: OrderOptionType.updateDate, asc: false)],
    );
    final filterOption = FilterOption(needTitle: true);
    filterOptionGroup.setOption(AssetType.image, filterOption);
    filterOptionGroup.setOption(AssetType.video, filterOption);

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: false,
      onlyAll: false,
      filterOption: filterOptionGroup,
    );

    if (albums.isEmpty) {
      return [];
    }

    final List<AssetPathEntity> dcimAlbum = albums
        .where((album) => album.name.toLowerCase() == 'dcim')
        .toList();

    return albums.map((AssetPathEntity album) {
      return Album(id: album.id, title: album.name);
    }).toList();
  }

  @override
  Future<List<MediaAsset>> getMediaAssetsInAlbum({
    required String albumId,
    int page = 0,
    int limit = 100,
  }) async {
    try {
      final AssetPathEntity targetAlbum = await AssetPathEntity.fromId(albumId);

      final List<AssetEntity> assetEntities = await targetAlbum
          .getAssetListPaged(page: 0, size: 100);

      final List<MediaAsset> mediaAssets = assetEntities.map((asset) {
        return toMediaAsset(asset);
      }).toList();

      return mediaAssets;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> moveAssetsToAlbum(String albumId, List<String> assetIds) {
    // TODO: implement moveAssetsToAlbum
    throw UnimplementedError();
  }
}

final androidAlbumRepoProvider = Provider((ref) {
  return AndroidAlbumRepo();
});
