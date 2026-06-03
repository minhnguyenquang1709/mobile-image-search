import 'package:flutter/rendering.dart';
import 'package:mobile_image_search/objectbox.g.dart';
import 'package:mobile_image_search/src/core/platform_image_method_channel.dart';
import 'package:mobile_image_search/src/feature/gallery/data/objectbox_trash_entry.dart';
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
  ///
  /// TODO: optimize, the filtering out trashed album step is too slow
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

    // get album trash entries
    final albumTrashBox = _objectBoxClient.store
        .box<ObjectBoxAlbumTrashEntry>();
    final List<ObjectBoxAlbumTrashEntry> albumTrashEntries = albumTrashBox
        .getAll();
    final Set<String> trashedAlbumIds = albumTrashEntries
        .map((e) => e.albumId)
        .toSet();
    debugPrint("[AndroidAlbumRepository] Trashed album IDs: $trashedAlbumIds");

    final List<Album> visibleAlbums = [];
    for (final album in albums) {
      // filter out albums that all assets are in trash
      final bool isAlbumTrashed = trashedAlbumIds.contains(album.id);
      if (!isAlbumTrashed) {
        visibleAlbums.add(Album(id: album.id, title: album.name));
      }
    }
    return visibleAlbums;
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
  Future<Album> createAlbum(String albumTitle, [String? description]) async {
    try {
      // check existing album with the same name
      if (await isAlbumExist(albumTitle)) {
        debugPrint(
          "[AndroidAlbumRepository] Album with name '$albumTitle' already exists",
        );
        throw Exception("Album with the same name already exists");
      }

      // create folder on platform first
      final Map<String, dynamic> params = {'albumTitle': albumTitle};
      final String? newAlbumBucketId = await _platformChannelClient
          .invokeMethod<String>("createAlbum", params);
      if (newAlbumBucketId == null) {
        throw Exception("Failed to create album on platform");
      }

      // then create objectbox entry
      final albumBox = _objectBoxClient.store.box<ObjectBoxAlbum>();
      final ObjectBoxAlbum newObjectBoxAlbum = ObjectBoxAlbum(
        title: albumTitle,
        description: description,
        platformId: newAlbumBucketId,
      );
      final newAlbumId = await albumBox.putAsync(newObjectBoxAlbum);

      // Return a temporary Album object (empty directories are not indexed by Android MediaStore)
      return Album(id: newAlbumId.toString(), title: albumTitle);
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

  /// Update the album list in the app database by syncing with the platform albums.
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

      // delete trashed album entries if the album no longer exists on platform
      final albumTrashBox = _objectBoxClient.store
          .box<ObjectBoxAlbumTrashEntry>();
      final List<ObjectBoxAlbumTrashEntry> albumTrashEntries = albumTrashBox
          .getAll();
      for (final trashEntry in albumTrashEntries) {
        final bool doesAlbumExistOnPlatform = nativeAlbums.any(
          (album) => album.id == trashEntry.albumId,
        );
        if (!doesAlbumExistOnPlatform) {
          await albumTrashBox.removeAsync(trashEntry.id);
          debugPrint(
            "[AndroidAlbumRepository] Removed trashed album entry for albumId ${trashEntry.albumId} as it no longer exists on platform",
          );
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> moveToTrash(List<MediaAsset> assets) async {
    final box = _objectBoxClient.store.box<ObjectBoxTrashEntry>();

    // filter out assets already in trash
    final existingIds = box.getAll().map((e) => e.assetId).toSet();
    final newAssets = assets
        .where((a) => !existingIds.contains(a.assetId))
        .toList();

    if (newAssets.isEmpty) return;

    final entries = newAssets
        .map(
          (asset) => ObjectBoxTrashEntry(
            assetId: asset.assetId,
            trashedAt: DateTime.now(),
          ),
        )
        .toList();

    await box.putManyAsync(entries);

    debugPrint("Moved ${entries.length} items to trash");
  }

  Future<void> revertMoveToTrash(List<MediaAsset> mediaAssetList) async {
    final box = _objectBoxClient.store.box<ObjectBoxTrashEntry>();
    final assetIds = mediaAssetList.map((a) => a.assetId).toList();

    // Find all trash entries that match the given asset IDs
    final query = box
        .query(ObjectBoxTrashEntry_.assetId.oneOf(assetIds))
        .build();
    final entries = query.find();
    query.close();

    if (entries.isEmpty) return;

    final internalIds = entries.map((e) => e.id).toList();
    await box.removeManyAsync(internalIds);

    debugPrint("Reverted move to trash for ${internalIds.length} items");
  }

  /// Delete the album with the given BUCKET_ID.
  ///
  /// - create TrashEntry for each media asset in the album
  ///
  /// - create trash entry for album in app database
  @override
  Future<void> deleteAlbum(String albumId, {bool deleteAssets = false}) async {
    try {
      // get all media assets in the album
      final AssetPathEntity album = await AssetPathEntity.fromId(albumId);

      bool hasMore = true;
      int page = 0;
      final List<MediaAsset> albumMediaAssets = [];
      while (hasMore) {
        final List<AssetEntity> currentPageAssetList = await album
            .getAssetListPaged(page: page, size: 200);

        albumMediaAssets.addAll(
          currentPageAssetList.map((asset) => toMediaAsset(asset)).toList(),
        );

        if (currentPageAssetList.isEmpty) {
          hasMore = false;
        }
        page++;
      }

      // create TrashEntry for each media asset
      try {
        if (albumMediaAssets.isNotEmpty) {
          await moveToTrash(albumMediaAssets);
        }
      } catch (e) {
        await revertMoveToTrash(albumMediaAssets);
      }

      // create album trash entry in database
      final albumTrashBox = _objectBoxClient.store
          .box<ObjectBoxAlbumTrashEntry>();
      final ObjectBoxAlbumTrashEntry albumTrashEntry = ObjectBoxAlbumTrashEntry(
        albumId: albumId,
        trashedAt: DateTime.now(),
      );
      await albumTrashBox.putAsync(albumTrashEntry);
    } catch (e) {
      rethrow;
    }
  }
}
