import 'package:mobile_image_search/src/feature/gallery/data/trash_model.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

abstract class ITrashRepository {
  /// Fetch all trashed media entries from the app-managed trash container
  Future<List<TrashEntry>> getAllTrashEntries();

  /// Move the given media assets to the app-managed trash container
  ///
  /// The trashed media will not be visible in the main collection, but can be accessed via the trash screen.
  Future<void> moveToTrash(List<MediaAsset> assets);

  /// Restore the media with the given assetIds from trash back to main collection
  ///
  /// Simply delete the trash entry from ObjectBox, so that the media asset will be visible again in the main collection.
  Future<void> restoreFromTrash(List<String> assetIds);

  /// Permanently delete the media with the given assetIds from the device
  Future<void> deletePermanently(List<String> assetIds);
}
