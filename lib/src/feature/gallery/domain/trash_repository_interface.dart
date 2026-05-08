import 'package:mobile_image_search/src/feature/gallery/data/trash_model.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

abstract class ITrashRepository {
  Future<List<TrashItem>> getAllTrashItems();

  Future<void> moveToTrash(List<MediaAsset> assets);

  Future<void> restoreFromTrash(List<String> assetIds);

  Future<void> deletePermanently(List<String> assetIds);
}
