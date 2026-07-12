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
import 'package:mobile_image_search/src/core/utils/exceptions.dart';
import 'package:photo_manager/photo_manager.dart';

class AndroidAlbumRepository implements IAlbumRepository {
  final PlatformChannelService _platformChannelClient;
  final ObjectBoxService _objectBoxClient;

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
        // resolve the directory path so same-named albums can be told apart
        final String? path = await _resolvePathForAssetPath(album);
        visibleAlbums.add(Album(id: album.id, title: album.name, path: path));
      }
    }
    return visibleAlbums;
  }

  /// Read the directory path (MediaStore RELATIVE_PATH) of an album by sampling
  /// one of its assets. Returns null if it can't be resolved.
  ///
  /// TODO: optimize, one query per album is slow; consider a native batch query.
  Future<String?> _resolvePathForAssetPath(AssetPathEntity path) async {
    try {
      final assets = await path.getAssetListPaged(page: 0, size: 1);
      if (assets.isNotEmpty) {
        final AssetEntity sample = assets.first;
        final String? relativePath = sample.relativePath;
        if (relativePath != null && relativePath.isNotEmpty) {
          return relativePath;
        }
        // fallback: derive it from the file's absolute directory
        final file = await sample.file;
        if (file != null) {
          final String dir = file.parent.path;
          const String prefix = "/storage/emulated/0/";
          return dir.startsWith(prefix) ? dir.substring(prefix.length) : dir;
        }
      }
    } catch (e) {
      debugPrint(
        "[AndroidAlbumRepository] Could not resolve path for ${path.name}: $e",
      );
    }
    return null;
  }

  /// Resolve the destination folder (MediaStore RELATIVE_PATH) for [album].
  ///
  /// For an existing album  read the folder of one of its assets so the move
  /// lands in the SAME bucket (otherwise a second folder with the same name is
  /// created). For a freshly created/empty album  fall back to the app
  /// convention `DCIM/<title>` (matching native `createAlbum`).
  Future<String> _resolveAlbumRelativePath(Album album) async {
    // already resolved when the album list was built, reuse it
    if (album.path != null && album.path!.isNotEmpty) {
      return album.path!;
    }

    try {
      final AssetPathEntity path = await AssetPathEntity.fromId(album.id);
      final String? relativePath = await _resolvePathForAssetPath(path);
      if (relativePath != null && relativePath.isNotEmpty) {
        return relativePath;
      }
    } catch (e) {
      debugPrint(
        "[AndroidAlbumRepository] Could not resolve album path, defaulting to DCIM: $e",
      );
    }
    return "DCIM/${album.title}";
  }

  /// Whether MediaStore.insert() can write into [relativePath]'s top-level folder.
  /// Non-standard folders (e.g. "mid_math_problem/") must go through SAF instead.
  bool _isMediaStoreWritable(String relativePath) {
    final String primary = relativePath
        .split('/')
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    const allowed = {'DCIM'};
    return allowed.contains(primary);
  }

  /// Move [assets] into [album]: native copies each file
  /// (streaming progress), then  run a single batch delete of the originals
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
    debugPrint(
      "[AndroidAlbumRepository] Move dest: album='${album.title}' "
      "(id=${album.id}) -> relativePath='$relativePath'",
    );

    if (_isMediaStoreWritable(relativePath)) {
      // standard media folder, MediaStore can insert directly, no prompt
      final stream = _platformChannelClient.moveMediaToAlbumStream(
        relativePath: relativePath,
        assets: assets,
      );
      _attachMoveListener(controller, stream, assets, total);
    } else {
      // non-standard folder, needs a one-time SAF grant before  can write
      final String? treeUri = await _platformChannelClient.ensureFolderAccess(
        relativePath,
      );
      if (treeUri == null) {
        controller.add(
          MoveProgress(
            total: total,
            processed: 0,
            isMoving: false,
            state: MoveState.denied,
          ),
        );
        await controller.close();
        return;
      }

      final stream = _platformChannelClient.moveMediaToAlbumSafStream(
        treeUri: treeUri,
        assets: assets,
      );
      _attachMoveListener(controller, stream, assets, total);
    }
  }

  /// Forward native copy events ([stream]) to [controller], then run the
  /// originals-delete consent once copies are done. Shared by the MediaStore and
  /// SAF move paths (their event contract is identical).
  void _attachMoveListener(
    StreamController<MoveProgress> controller,
    Stream<dynamic> stream,
    List<MediaAsset> assets,
    int total,
  ) {
    // copies created so far (new MediaStore ids) + their SAF doc Uri (null for
    // MediaStore copies), in the same order as [assets]
    final List<int> newAssetIds = [];
    final List<String?> docUris = [];

    late final StreamSubscription subscription;
    subscription = stream.listen(
      (event) async {
        final Map<dynamic, dynamic> map = event as Map<dynamic, dynamic>;
        final String state = map['state'] as String;

        if (state == 'copying') {
          final int index = map['index'] as int;
          newAssetIds.add(map['newAssetId'] as int);
          docUris.add(map['docUri'] as String?);
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
          // copies done, now ask the user to confirm deleting the originals
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
                .confirmDeleteOriginals(assets, newAssetIds, docUris);
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
    // reject a name already used by a device album or an app record
    final List<Album> deviceAlbums = await getAlbums();
    final bool existsOnDevice = deviceAlbums.any(
      (a) => a.title.toLowerCase() == albumTitle.toLowerCase(),
    );
    if (existsOnDevice || await isAlbumExist(albumTitle)) {
      throw InvalidAlbumNameException(
        "An album named '$albumTitle' already exists.",
      );
    }

    // create the real folder on the platform (drops a placeholder cover in it
    // so the folder is listed as an album). Replies bucketId + relativePath.
    final Map<String, dynamic> params = {'albumTitle': albumTitle};
    final result = await _platformChannelClient
        .invokeMethod<Map<dynamic, dynamic>>("createAlbum", params);
    if (result == null || result["bucketId"] == null) {
      throw Exception("Failed to create album on device");
    }
    final String bucketId = result["bucketId"].toString();
    final String? relativePath = result["relativePath"]?.toString();

    // save the app database record
    final albumBox = _objectBoxClient.store.box<ObjectBoxAlbum>();
    final ObjectBoxAlbum newObjectBoxAlbum = ObjectBoxAlbum(
      title: albumTitle,
      description: description,
      platformId: bucketId,
    );
    await albumBox.putAsync(newObjectBoxAlbum);

    return Album(
      id: bucketId,
      title: albumTitle,
      path: relativePath,
      description: description,
    );
  }

  /// Whether an album with [albumName] already exists in the app database.
  ///
  /// DB is the source of truth,  no longer probe public storage (that needed
  /// All-files access).
  Future<bool> isAlbumExist(String albumName) async {
    try {
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
      return false;
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

  /// Permanently delete the album with the given BUCKET_ID.
  ///
  /// 1. permanently delete its image/video files via MediaStore (user consent)
  /// 2. try to delete the directory itself, left in place if it still holds
  ///    non-media files, deleted (via SAF) if media was all it contained
  /// 3. remove the album's app-database record
  ///
  /// Returns the ids of the media that were permanently deleted so the caller
  /// can clean up their embeddings and trash entries.
  @override
  Future<List<String>> deleteAlbum(
    String albumId, {
    bool deleteAssets = false,
  }) async {
    try {
      final AssetPathEntity album = await AssetPathEntity.fromId(albumId);

      // resolve the directory path now, while the album still has assets
      final String? relativePath = await _resolvePathForAssetPath(album);

      // gather all media in the album (ids + types)
      bool hasMore = true;
      int page = 0;
      final List<MediaAsset> albumMediaAssets = [];
      while (hasMore) {
        final List<AssetEntity> currentPageAssetList = await album
            .getAssetListPaged(page: page, size: 200);

        if (currentPageAssetList.isEmpty) {
          hasMore = false;
        } else {
          albumMediaAssets.addAll(
            currentPageAssetList.map((asset) => toMediaAsset(asset)),
          );
          page++;
        }
      }

      // permanently delete the media (system consent dialog)
      if (albumMediaAssets.isNotEmpty) {
        final bool deleted = await _platformChannelClient
            .permanentlyDeleteAlbumMedia(albumMediaAssets);
        if (!deleted) {
          debugPrint(
            "[AndroidAlbumRepository] Album media deletion denied; aborting",
          );
          return [];
        }
      }

      // try to remove the now media-free directory (needs a SAF grant)
      if (relativePath != null && relativePath.isNotEmpty) {
        final String? treeUri = await _platformChannelClient.ensureFolderAccess(
          relativePath,
        );
        if (treeUri != null) {
          final bool dirDeleted = await _platformChannelClient
              .deleteAlbumDirectory(treeUri);
          debugPrint(
            "[AndroidAlbumRepository] Album directory deleted: $dirDeleted",
          );
        }
      }

      // remove the album's database record
      final albumBox = _objectBoxClient.store.box<ObjectBoxAlbum>();
      final query = albumBox
          .query(ObjectBoxAlbum_.platformId.equals(albumId))
          .build();
      final dbAlbums = query.find();
      query.close();
      if (dbAlbums.isNotEmpty) {
        await albumBox.removeManyAsync(
          dbAlbums.map((a) => a.objectBoxId).toList(),
        );
      }

      return albumMediaAssets.map((asset) => asset.assetId).toList();
    } catch (e) {
      rethrow;
    }
  }
}
