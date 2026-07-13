import 'package:mobile_image_search/src/feature/gallery/data/trash_model.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

abstract class ITrashRepository {
  Future<List<TrashEntry>> getAllTrashEntries();

  Future<void> moveToTrash(List<MediaAsset> assets);

  Future<void> restoreFromTrash(List<String> assetIds);

  Future<void> deletePermanently(List<MediaAsset> assets);

  /// Remove only the trash entries for [assetIds], without touching the device
  /// files. Use when the files were already deleted elsewhere.
  Future<void> removeTrashEntries(List<String> assetIds);
}
