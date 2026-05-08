import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/feature/gallery/data/trash_model.dart';
import 'package:mobile_image_search/src/feature/gallery/domain/trash_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

class AndroidTrashRepository implements ITrashRepository {
  @override
  Future<void> deletePermanently(List<String> assetIds) {
    // TODO: implement deletePermanently
    throw UnimplementedError();
  }

  @override
  Future<List<TrashItem>> getAllTrashItems() {
    // TODO: implement getAllTrashItems
    throw UnimplementedError();
  }

  @override
  Future<void> moveToTrash(List<MediaAsset> assets) async {
    debugPrint(
      "[AndroidTrashRepository] moveToTrash called with ${assets.length} assets",
    );

    // TODO: start bulk operation
  }

  @override
  Future<void> restoreFromTrash(List<String> assetIds) {
    // TODO: implement restoreFromTrash
    throw UnimplementedError();
  }
}

final trashRepositoryProvider = Provider<ITrashRepository>((ref) {
  return AndroidTrashRepository();
});
