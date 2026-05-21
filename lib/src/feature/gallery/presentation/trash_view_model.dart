import 'package:flutter/foundation.dart';
import 'package:mobile_image_search/src/service_locator.dart';

/// ViewModel for Trash Screen
/// Holds state about trashed media across the entire app
class TrashViewModel extends ChangeNotifier {
  static final TrashViewModel instance = TrashViewModel._();

  TrashViewModel._();

  final Set<String> _trashedAssetIds = {};
  Set<String> get trashedAssetIds => Set.unmodifiable(_trashedAssetIds);

  Future<void> loadFromDatabase() async {
    debugPrint("[TrashViewModel] Loading trashed asset IDs from database...");
    try {
      final entries = await ServiceLocator.trashService.loadTrash();
      _trashedAssetIds.clear();
      _trashedAssetIds.addAll(entries.map((e) => e.assetId));
      notifyListeners();
      debugPrint(
        "[TrashViewModel] Loaded ${_trashedAssetIds.length} trashed items",
      );
    } catch (e) {
      debugPrint("[TrashViewModel] Error loading from database: $e");
      rethrow;
    }
  }

  void markAsTrashed(List<String> assetIds) {
    _trashedAssetIds.addAll(assetIds);
    notifyListeners();
  }

  Future<void> restoreTrashedMedia(List<String> assetIds) async {
    if (assetIds.isEmpty) return;

    debugPrint(
      "[TrashViewModel] Restoring ${assetIds.length} items from trash",
    );

    // Filter to only IDs that are actually in trash
    final toRestore = assetIds
        .where((id) => _trashedAssetIds.contains(id))
        .toList();
    if (toRestore.isEmpty) {
      debugPrint("[TrashViewModel] No matching trashed items to restore");
      return;
    }

    try {
      await ServiceLocator.trashService.restore(toRestore);
      _trashedAssetIds.removeAll(toRestore);
      notifyListeners();
      debugPrint("[TrashViewModel] Successfully restored $toRestore");
    } catch (e) {
      debugPrint("[TrashViewModel] Error restoring: $e");
      rethrow;
    }
  }

  Future<void> emptyTrash(List<String> assetIds) async {
    if (assetIds.isEmpty) return;

    debugPrint(
      "[TrashViewModel] Permanently deleting ${assetIds.length} items",
    );

    try {
      await ServiceLocator.trashService.emptyTrash(assetIds);
      _trashedAssetIds.removeAll(assetIds);
      notifyListeners();
      debugPrint("[TrashViewModel] Successfully deleted items");
    } catch (e) {
      debugPrint("[TrashViewModel] Error deleting: $e");
      rethrow;
    }
  }
}
