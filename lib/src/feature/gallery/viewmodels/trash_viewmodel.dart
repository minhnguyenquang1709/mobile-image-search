import 'package:flutter/widgets.dart';
import 'package:mobile_image_search/src/core/utils/exceptions.dart';
import 'package:mobile_image_search/src/data/interfaces/image_embedding_repository_interface.dart';
import 'package:mobile_image_search/src/data/interfaces/media_asset_repository_interface.dart';
import 'package:mobile_image_search/src/data/interfaces/trash_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

/// ViewModel for Trash Screen
/// Holds state about trashed media across the entire app
class TrashViewModel extends ChangeNotifier {
  final ITrashRepository _trashRepo;
  final IMediaAssetRepository _mediaAssetRepo;
  final IImageEmbeddingRepository _imageEmbeddingRepo;

  TrashViewModel({
    required ITrashRepository trashRepo,
    required IMediaAssetRepository mediaAssetRepo,
    required IImageEmbeddingRepository imageEmbeddingRepo,
  }) : _trashRepo = trashRepo,
       _mediaAssetRepo = mediaAssetRepo,
       _imageEmbeddingRepo = imageEmbeddingRepo;

  final Set<String> _trashedAssetIds = {};
  Set<String> get trashedAssetIds => Set.unmodifiable(_trashedAssetIds);

  List<MediaAsset> trashedMediaAssets = [];

  Future<void> loadFromDatabase() async {
    debugPrint("[TrashViewModel] Loading trashed asset IDs from database...");
    try {
      final entries = await _trashRepo.getAllTrashEntries();
      _trashedAssetIds.clear();
      _trashedAssetIds.addAll(entries.map((e) => e.assetId));
      trashedMediaAssets = await Future.wait(
        _trashedAssetIds.map((String assetId) {
          return _mediaAssetRepo.getMediaAssetById(assetId);
        }).toList(),
      );
      notifyListeners();
      debugPrint(
        "[TrashViewModel] Loaded ${_trashedAssetIds.length} trashed items",
      );
    } catch (e) {
      debugPrint("[TrashViewModel] Error loading from database: $e");
      rethrow;
    }
  }

  /// Move the given media to trash and update the app-wide trashed state so
  /// gallery/album screens hide them and the trash screen shows them.
  Future<void> moveToTrash(List<MediaAsset> mediaAssets) async {
    if (mediaAssets.isEmpty) return;

    debugPrint("[TrashViewModel] Moving ${mediaAssets.length} items to trash");

    try {
      await _trashRepo.moveToTrash(mediaAssets);

      for (final asset in mediaAssets) {
        if (_trashedAssetIds.add(asset.assetId)) {
          trashedMediaAssets.add(asset);
        }
      }
      notifyListeners();
      debugPrint("[TrashViewModel] Successfully moved items to trash");
    } catch (e) {
      debugPrint("[TrashViewModel] Error moving to trash: $e");
      rethrow;
    }
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
      await _trashRepo.restoreFromTrash(toRestore);
      _trashedAssetIds.removeAll(toRestore);
      notifyListeners();
      debugPrint("[TrashViewModel] Successfully restored $toRestore");
    } catch (e) {
      debugPrint("[TrashViewModel] Error restoring: $e");
      rethrow;
    }
  }

  Future<void> permanentlyDelete(List<String> assetIds) async {
    if (assetIds.isEmpty) return;

    debugPrint(
      "[TrashViewModel] Permanently deleting ${assetIds.length} items",
    );

    try {
      // remove trash entries & media files from device storage
      await _trashRepo.deletePermanently(assetIds);
      _trashedAssetIds.removeAll(assetIds);

      // remove corresponding embedding from db

      notifyListeners();
      debugPrint("[TrashViewModel] Successfully deleted items");
    } catch (e) {
      debugPrint("[TrashViewModel] Error deleting: $e");
      rethrow;
    }
  }

  Future<MediaAsset> getMediaAssetById(String assetId) async {
    try {
      return await _mediaAssetRepo.getMediaAssetById(assetId);
    } catch (e) {
      debugPrint("[TrashViewModel] Error fetching asset by ID '$assetId': $e");
      throw MediaAssetNotFoundException(assetId);
    }
  }

  ImageProvider thumbnailProviderFor(String assetId) {
    return _mediaAssetRepo.thumbnailProviderFor(assetId);
  }
}
