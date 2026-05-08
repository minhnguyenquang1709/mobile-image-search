import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/feature/gallery/application/trash_service.dart';
import 'package:mobile_image_search/src/feature/gallery/data/trash_model.dart';

class TrashController extends AutoDisposeAsyncNotifier<TrashState> {
  @override
  FutureOr<TrashState> build() async {
    final service = ref.read(trashServiceProvider);
    final items = await service.loadTrash();
    return TrashState(items: items);
  }

  void toggleSelect(String assetId) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = Set<String>.from(current.selectedAssetIds);
    if (updated.contains(assetId)) {
      updated.remove(assetId);
    } else {
      updated.add(assetId);
    }

    state = AsyncValue.data(current.copyWith(selectedAssetIds: updated));
  }

  void clearSelection() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(selectedAssetIds: {}));
  }

  Future<void> restoreSelected() async {
    final current = state.valueOrNull;
    if (current == null || current.selectedAssetIds.isEmpty) return;

    state = AsyncValue.data(current.copyWith(isLoading: true));

    try {
      final service = ref.read(trashServiceProvider);
      await service.restore(current.selectedAssetIds.toList());

      final remaining = current.items
          .where((i) => !current.selectedAssetIds.contains(i.asset.assetId))
          .toList();

      state = AsyncValue.data(
        current.copyWith(
          items: remaining,
          selectedAssetIds: {},
          isLoading: false,
        ),
      );
    } catch (e) {
      state = AsyncValue.data(current.copyWith(isLoading: false));
    }
  }

  Future<void> deleteSelectedPermanently() async {
    final current = state.valueOrNull;
    if (current == null || current.selectedAssetIds.isEmpty) return;

    state = AsyncValue.data(current.copyWith(isLoading: true));

    try {
      final service = ref.read(trashServiceProvider);
      await service.emptyTrash(current.selectedAssetIds.toList());

      final remaining = current.items
          .where((i) => !current.selectedAssetIds.contains(i.asset.assetId))
          .toList();

      state = AsyncValue.data(
        current.copyWith(
          items: remaining,
          selectedAssetIds: {},
          isLoading: false,
        ),
      );
    } catch (e) {
      state = AsyncValue.data(current.copyWith(isLoading: false));
    }
  }
}

final trashControllerProvider =
    AsyncNotifierProvider.autoDispose<TrashController, TrashState>(
      TrashController.new,
    );
