import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/objectbox.g.dart';
import 'package:mobile_image_search/src/feature/gallery/data/objectbox_trash_entry.dart';
import 'package:mobile_image_search/src/feature/gallery/data/trash_model.dart';
import 'package:mobile_image_search/src/feature/gallery/domain/trash_repository_interface.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_repository.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

class AndroidTrashRepository implements ITrashRepository {
  final ObjectBoxClient _objectBoxClient;

  AndroidTrashRepository({required objectBoxStoreClient})
    : _objectBoxClient = objectBoxStoreClient;

  @override
  Future<void> deletePermanently(List<String> assetIds) {
    // TODO: implement deletePermanently
    throw UnimplementedError();
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
            (e) => TrashEntry(
              id: e.id.toString(),
              assetId: e.assetId,
              trashedAt: e.trashedAt,
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
  }
}

final trashRepositoryProvider = Provider<ITrashRepository>((ref) {
  final objectBoxClient = ref.watch(objectBoxClientProvider).requireValue;

  return AndroidTrashRepository(objectBoxStoreClient: objectBoxClient);
});
