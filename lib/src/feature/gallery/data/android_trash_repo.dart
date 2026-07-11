import 'package:flutter/foundation.dart';
import 'package:mobile_image_search/objectbox.g.dart';
import 'package:mobile_image_search/src/core/platform_image_method_channel.dart';
import 'package:mobile_image_search/src/feature/gallery/data/objectbox_trash_entry.dart';
import 'package:mobile_image_search/src/feature/gallery/data/trash_model.dart';
import 'package:mobile_image_search/src/data/interfaces/trash_repository_interface.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_repository.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

class AndroidTrashRepository implements ITrashRepository {
  final ObjectBoxService _objectBoxClient;
  final PlatformChannelService _methodChannel;

  AndroidTrashRepository({
    required ObjectBoxService objectBoxStoreClient,
    required PlatformChannelService methodChannel,
  }) : _objectBoxClient = objectBoxStoreClient,
       _methodChannel = methodChannel;

  /// Send message to native platform to permanently delete media assets
  @override
  Future<void> deletePermanently(List<String> assetIds) async {
    debugPrint(
      "[AndroidTrashRepository] Permanently deleting assetIds: $assetIds",
    );
    try {
      Map<String, dynamic> args = {
        'opId': 'permanentlyDelete',
        'assetIds': assetIds,
      };
      await _methodChannel.callNativeMethod("permanentlyDelete", args);

      // remove any corresponding trash entries from ObjectBox
      final trashEntryBox = _objectBoxClient.store.box<ObjectBoxTrashEntry>();
      final entriesToDelete = trashEntryBox
          .query(ObjectBoxTrashEntry_.assetId.oneOf(assetIds))
          .build()
          .find();
      if (entriesToDelete.isNotEmpty) {
        final idsToDelete = entriesToDelete.map((e) => e.id).toList();
        await trashEntryBox.removeManyAsync(idsToDelete);
        debugPrint(
          "Deleted ${idsToDelete.length} entries from ObjectBox after permanent deletion",
        );
      } else {
        debugPrint(
          "No matching entries found in ObjectBox for assetIds: $assetIds after permanent deletion",
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<TrashEntry>> getAllTrashEntries() {
    debugPrint(
      "[AndroidTrashRepository] Fetching all trash entries from ObjectBox...",
    );
    final box = _objectBoxClient.store.box<ObjectBoxTrashEntry>();
    final entries = box.getAll();

    return Future.value(
      entries
          .map(
            (dbTrashEntry) => TrashEntry(
              // id: dbTrashEntry.id.toString(),
              assetId: dbTrashEntry.assetId,
              trashedAt: dbTrashEntry.trashedAt,
            ),
          )
          .toList(),
    );
  }

  @override
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

  @override
  Future<void> restoreFromTrash(List<String> assetIds) async {
    debugPrint("[AndroidTrashRepository] Restoring assetIds: $assetIds");

    final trashEntryBox = _objectBoxClient.store.box<ObjectBoxTrashEntry>();
    final entriesToRestore = trashEntryBox
        .query(ObjectBoxTrashEntry_.assetId.oneOf(assetIds))
        .build()
        .find();

    if (entriesToRestore.isEmpty) {
      debugPrint("No matching entries found in trash for assetIds: $assetIds");
      return;
    }

    // delete entries from DB
    final idsToDelete = entriesToRestore.map((e) => e.id).toList();
    await trashEntryBox.removeManyAsync(idsToDelete);

    // delete album trash entries if any of the restored assets belong to trashed albums
  }
}
