import 'package:flutter/rendering.dart';
import 'package:mobile_image_search/objectbox.g.dart';
import 'package:mobile_image_search/src/core/platform_image_method_channel.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_repository.dart';
import 'package:mobile_image_search/src/shared/domain/interface/album_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/album.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:mobile_image_search/src/utils/media_processing.dart';
import 'package:photo_manager/photo_manager.dart';

class AndroidAlbumRepository implements IAlbumRepository {
  final PlatformChannelClient _platformChannelClient;
  final ObjectBoxClient _objectBoxClient;

  /// Directory in Android device where the app-created albums will be stored
  final String _appAlbumDir = "/storage/emulated/0/Pictures/SmartGallery";

  AndroidAlbumRepository({
    required PlatformChannelClient platformChannelClient,
    required ObjectBoxClient objectBoxClient,
  }) : _objectBoxClient = objectBoxClient,
       _platformChannelClient = platformChannelClient;

  /// Uses photo_manager to get the list of albums, represented by [AssetPathEntity]
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

    // final List<AssetPathEntity> dcimAlbum = albums
    //     .where((album) => album.name.toLowerCase() == 'dcim')
    //     .toList();

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

  @override
  Future<Album> createAlbum(String albumName, [String? description]) async {
    try {
      // check existing album with the same name
      if (await isAlbumExist(albumName)) {
        debugPrint(
          "[AndroidAlbumRepository] Album with name '$albumName' already exists",
        );
        throw Exception("Album with the same name already exists");
      }

      // create folder on platform first
      final Map<String, dynamic> params = {'albumTitle': albumName};
      final String? newAlbumBucketId = await _platformChannelClient
          .invokeMethod<String>("createAlbum", params);
      if (newAlbumBucketId == null) {
        throw Exception("Failed to create album on platform");
      }

      // then create objectbox entry
      final albumBox = _objectBoxClient.store.box<ObjectBoxAlbum>();
      final ObjectBoxAlbum newObjectBoxAlbum = ObjectBoxAlbum(
        title: albumName,
        description: description,
        platformId: newAlbumBucketId,
      );
      final newAlbumId = await albumBox.putAsync(newObjectBoxAlbum);

      // Return a temporary Album object (empty directories are not indexed by Android MediaStore)
      return Album(id: newAlbumId.toString(), title: albumName);
    } catch (e) {
      rethrow;
    }
  }

  /// Check
  ///
  /// - if a directory in the [_appAlbumDir] with the same name already exists on the platform
  ///
  /// - if an album with the same name already exists in the database
  Future<bool> isAlbumExist(String albumName) async {
    try {
      // check directory
      final bool? doesDirExist = await _platformChannelClient
          .invokeMethod<bool>('checkAlbumExistence', {
            'appAlbumDir': _appAlbumDir,
            'albumName': albumName,
          });

      // check database entry
      final albumBox = _objectBoxClient.store.box<ObjectBoxAlbum>();
      final existingAlbum = albumBox
          .query(ObjectBoxAlbum_.title.equals(albumName))
          .build()
          .findFirst();
      if (existingAlbum != null) {
        debugPrint(
          "[AndroidAlbumRepository] Album with name '$albumName' already exists in database",
        );
        return true;
      }

      if (doesDirExist == null) {
        throw Exception("Failed to check album existence");
      }
      return doesDirExist;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> syncAlbums() async {
    try {
      debugPrint(
        "[AndroidAlbumRepository] Syncing albums between platform and database...",
      );
      // get all platform albums (albums containing media)
      final List<AssetPathEntity> nativeAlbums =
          await PhotoManager.getAssetPathList(
            type: RequestType.common,
            hasAll: false,
            onlyAll: false,
            filterOption: FilterOptionGroup(
              orders: [
                const OrderOption(type: OrderOptionType.updateDate, asc: false),
              ],
            ),
          );

      // get all database albums
      final albumBox = _objectBoxClient.store.box<ObjectBoxAlbum>();
      final dbAlbums = albumBox.getAll();
      final dbAlbumTitles = dbAlbums.map((a) => a.title).toSet();

      // find platform albums that are not in the database
      final List<ObjectBoxAlbum> newAlbumsToInsert = [];
      for (final nativeAlbum in nativeAlbums) {
        if (!dbAlbumTitles.contains(nativeAlbum.name)) {
          newAlbumsToInsert.add(
            ObjectBoxAlbum(title: nativeAlbum.name, platformId: nativeAlbum.id),
          );
        }
      }

      // insert into the database
      if (newAlbumsToInsert.isNotEmpty) {
        albumBox.putMany(newAlbumsToInsert);
      }

      debugPrint(
        "[AndroidAlbumRepository] Sync completed. ${newAlbumsToInsert.length} new albums added to database.",
      );
    } catch (e) {
      rethrow;
    }
  }
}
