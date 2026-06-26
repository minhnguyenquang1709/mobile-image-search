import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:mobile_image_search/objectbox.g.dart';
import 'package:mobile_image_search/src/core/platform_image_method_channel.dart';
import 'package:mobile_image_search/src/feature/gallery/data/objectbox_trash_entry.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_repository.dart';
import 'package:mobile_image_search/src/shared/domain/interface/album_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/album.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:mobile_image_search/src/shared/domain/model/move_progress.dart';
import 'package:mobile_image_search/src/core/utils/media_processing.dart';
import 'package:photo_manager/photo_manager.dart';

class AndroidAlbumRepository implements IAlbumRepository {
  final PlatformChannelService _platformChannelClient;
  final ObjectBoxService _objectBoxClient;

  /// Directory in Android device where the app-created albums will be stored.
  ///
  /// Must match the root native uses in `createAlbum` and the move's
  /// RELATIVE_PATH (both DCIM), so album existence checks line up.
  final String _appAlbumDir = "/storage/emulated/0/DCIM";

  AndroidAlbumRepository({
    required PlatformChannelService platformChannelClient,
    required ObjectBoxService objectBoxClient,
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

  /// Resolve the destination folder (MediaStore RELATIVE_PATH) for [album].
  ///
  /// For an existing album we read the folder of one of its assets so the move
  /// lands in the SAME bucket (otherwise a second folder with the same name is
  /// created). For a freshly created/empty album we fall back to the app
  /// convention `DCIM/<title>` (matching native `createAlbum`).
  Future<String> _resolveAlbumRelativePath(Album album) async {
    try {
      final AssetPathEntity path = await AssetPathEntity.fromId(album.id);
      final assets = await path.getAssetListPaged(page: 0, size: 1);
      if (assets.isNotEmpty) {
        final AssetEntity sample = assets.first;

        // MediaStore RELATIVE_PATH (e.g. "Pictures/A/" or "DCIM/A/")
        final String? relativePath = sample.relativePath;
        if (relativePath != null && relativePath.isNotEmpty) {
          return relativePath;
        }

        // fallback: derive it from the file's absolute directory
        final file = await sample.file;
        if (file != null) {
          final String dir = file.parent.path; // /storage/emulated/0/Pictures/A
          const String prefix = "/storage/emulated/0/";
          if (dir.startsWith(prefix)) {
            return dir.substring(prefix.length); // Pictures/A
          }
        }
      }
    } catch (e) {
      debugPrint(
        "[AndroidAlbumRepository] Could not resolve album path, defaulting to DCIM: $e",
      );
    }
    return "DCIM/${album.title}";
  }

  /// Move [assets] into [album]: native copies each file
  /// (streaming progress), then we run a single batch delete of the originals
  /// with user consent. Progress is surfaced through a broadcast stream.
  @override
  Stream<MoveProgress> moveAssetsToAlbum(Album album, List<MediaAsset> assets) {
    final StreamController<MoveProgress> controller =
        StreamController<MoveProgress>.broadcast();

    // resolve the destination folder first, then start the native copy stream
    _runMove(controller, album, assets);

    return controller.stream;
  }

  Future<void> _runMove(
    StreamController<MoveProgress> controller,
    Album album,
    List<MediaAsset> assets,
  ) async {
    final String relativePath = await _resolveAlbumRelativePath(album);

    final int total = assets.length;
    // copies created so far (new MediaStore ids), in the same order as [assets]
    final List<int> newAssetIds = [];

    final stream = _platformChannelClient.moveMediaToAlbumStream(
      relativePath: relativePath,
      assets: assets,
    );

    late final StreamSubscription subscription;
    subscription = stream.listen(
      (event) async {
        final Map<dynamic, dynamic> map = event as Map<dynamic, dynamic>;
        final String state = map['state'] as String;

        if (state == 'copying') {
          final int index = map['index'] as int;
          newAssetIds.add(map['newAssetId'] as int);
          controller.add(
            MoveProgress(
              total: total,
              processed: index + 1,
              isMoving: true,
              state: MoveState.copying,
              currentAssetId: map['assetId']?.toString(),
            ),
          );
        } else if (state == 'copied') {
          // copies done — now ask the user to confirm deleting the originals
          controller.add(
            MoveProgress(
              total: total,
              processed: total,
              isMoving: true,
              state: MoveState.awaitingConsent,
            ),
          );

          try {
            final bool deleted = await _platformChannelClient
                .confirmDeleteOriginals(assets, newAssetIds);
            controller.add(
              MoveProgress(
                total: total,
                processed: total,
                isMoving: false,
                state: deleted ? MoveState.done : MoveState.denied,
              ),
            );
          } catch (e) {
            debugPrint("[AndroidAlbumRepository] Delete consent failed: $e");
            // PERMISSION_DENIED (copies rolled back natively) or other failure
            controller.add(
              MoveProgress(
                total: total,
                processed: total,
                isMoving: false,
                state: MoveState.denied,
              ),
            );
          }

          await subscription.cancel();
          await controller.close();
        } else if (state == 'error') {
          debugPrint("[AndroidAlbumRepository] Move error: ${map['message']}");
          controller.add(
            MoveProgress(
              total: total,
              processed: (map['index'] as int?) ?? 0,
              isMoving: false,
              state: MoveState.error,
            ),
          );
          await subscription.cancel();
          await controller.close();
        }
      },
      onError: (e) async {
        debugPrint("[AndroidAlbumRepository] Move stream error: $e");
        controller.add(
          MoveProgress(
            total: total,
            processed: 0,
            isMoving: false,
            state: MoveState.error,
          ),
        );
        await controller.close();
      },
    );
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
