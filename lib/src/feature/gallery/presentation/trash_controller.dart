import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/feature/gallery/application/trash_service.dart';
import 'package:mobile_image_search/src/feature/gallery/data/trash_model.dart';
import 'package:mobile_image_search/src/service_locator.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:mobile_image_search/src/utils/media_processing.dart';
import 'package:photo_manager/photo_manager.dart';

// class TrashController extends AutoDisposeAsyncNotifier<TrashState> {
//   @override
//   FutureOr<TrashState> build() async {
//     final trashService = ServiceLocator.trashService;
//     final items = await trashService.loadTrash();
//     debugPrint(
//       "TrashController loaded ${items.length} items from TrashService",
//     );
//     return TrashState(items: items);
//   }

//   void toggleSelect(String assetId) {
//     final current = state.valueOrNull;
//     if (current == null) return;

//     final updated = Set<String>.from(current.selectedAssetIds);
//     if (updated.contains(assetId)) {
//       updated.remove(assetId);
//     } else {
//       updated.add(assetId);
//     }

//     state = AsyncValue.data(current.copyWith(selectedAssetIds: updated));
//   }

//   void clearSelection() {
//     final current = state.valueOrNull;
//     if (current == null) return;
//     state = AsyncValue.data(current.copyWith(selectedAssetIds: {}));
//   }

//   Future<void> restoreSelected() async {
//     final current = state.valueOrNull;
//     if (current == null || current.selectedAssetIds.isEmpty) return;

//     state = AsyncValue.data(current.copyWith(isLoading: true));

//     try {
//       final trashService = ServiceLocator.trashService;
//       await trashService.restore(current.selectedAssetIds.toList());

//       final remaining = current.items
//           .where((i) => !current.selectedAssetIds.contains(i.assetId))
//           .toList();

//       state = AsyncValue.data(
//         current.copyWith(
//           items: remaining,
//           selectedAssetIds: {},
//           isLoading: false,
//         ),
//       );
//     } catch (e) {
//       state = AsyncValue.data(current.copyWith(isLoading: false));
//     }
//   }

//   Future<void> deleteSelectedPermanently() async {
//     final current = state.valueOrNull;
//     if (current == null || current.selectedAssetIds.isEmpty) return;

//     state = AsyncValue.data(current.copyWith(isLoading: true));

//     try {
//       final trashService = ServiceLocator.trashService;
//       await trashService.emptyTrash(current.selectedAssetIds.toList());

//       final remaining = current.items
//           .where((i) => !current.selectedAssetIds.contains(i.assetId))
//           .toList();

//       state = AsyncValue.data(
//         current.copyWith(
//           items: remaining,
//           selectedAssetIds: {},
//           isLoading: false,
//         ),
//       );
//     } catch (e) {
//       state = AsyncValue.data(current.copyWith(isLoading: false));
//     }
//   }
// }

// final trashControllerProvider =
//     AsyncNotifierProvider.autoDispose<TrashController, TrashState>(
//       TrashController.new,
//     );

// // Lazily fetch the MediaAsset given an assetId
// final mediaAssetProvider = FutureProvider.autoDispose
//     .family<MediaAsset?, String>((ref, id) async {
//       final assetEntity = await AssetEntity.fromId(id);
//       if (assetEntity == null) return null;

//       return toMediaAsset(assetEntity);
//     });
