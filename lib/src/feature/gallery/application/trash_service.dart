import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/feature/gallery/data/trash_model.dart';
import 'package:mobile_image_search/src/feature/gallery/data/android_trash_repo.dart';
import 'package:mobile_image_search/src/feature/gallery/domain/trash_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

class TrashService {
  final ITrashRepository repo;

  TrashService(this.repo);

  Future<List<TrashEntry>> loadTrash() => repo.getAllTrashEntries();

  Future<void> moveToTrash(List<MediaAsset> assets) => repo.moveToTrash(assets);

  Future<void> restore(List<String> assetIds) =>
      repo.restoreFromTrash(assetIds);

  Future<void> permanentlyDelete(List<String> assetIds) =>
      repo.deletePermanently(assetIds);
}

// final trashServiceProvider = FutureProvider<TrashService>((ref) async {
//   final repo = await ref.watch(trashRepositoryProvider);
//   return TrashService(repo);
// });
