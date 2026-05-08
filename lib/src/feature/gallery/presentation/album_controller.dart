import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/feature/gallery/application/album_service.dart';
import 'package:mobile_image_search/src/shared/domain/model/album.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

class AlbumController extends AsyncNotifier<List<Album>> {
  @override
  FutureOr<List<Album>> build() async {
    final albumService = ref.watch(albumServiceProvider);
    return albumService.getAlbums();
  }

  Future<void> getAlbums() async {
    state = const AsyncValue.loading();
    final albumService = ref.watch(albumServiceProvider);
    final albums = await albumService.getAlbums();
    state = AsyncValue.data(albums);
  }
}

final albumControllerProvider =
    AsyncNotifierProvider<AlbumController, List<Album>>(() {
      return AlbumController();
    });

@immutable
class AlbumDetailState {
  final List<MediaAsset> mediaAssets;
  final Set<String> selectedAssetIds;
  final bool isSelectionMode;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;

  const AlbumDetailState({
    required this.mediaAssets,
    this.selectedAssetIds = const {},
    this.isSelectionMode = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 0,
  });

  /// All MediaAsset objects that are currently selected
  List<MediaAsset> get selectedAssets =>
      mediaAssets.where((a) => selectedAssetIds.contains(a.assetId)).toList();

  AlbumDetailState copyWith({
    List<MediaAsset>? mediaAssets,
    Set<String>? selectedAssetIds,
    bool? isSelectionMode,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
  }) {
    return AlbumDetailState(
      mediaAssets: mediaAssets ?? this.mediaAssets,
      selectedAssetIds: selectedAssetIds ?? this.selectedAssetIds,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class AlbumDetailController
    extends AutoDisposeFamilyAsyncNotifier<AlbumDetailState, String> {
  static const int _pageSize = 40;

  // `arg` is the albumId, provided by the .family
  @override
  FutureOr<AlbumDetailState> build(String arg) async {
    final mediaAssets = await ref
        .watch(albumServiceProvider)
        .getMediaAssetsInAlbum(albumId: arg, page: 0, limit: _pageSize);

    return AlbumDetailState(
      mediaAssets: mediaAssets,
      // if we got fewer items than pageSize, there are no more pages
      hasMore: _countAssets(mediaAssets) >= _pageSize,
      currentPage: 0,
    );
  }

  // ── Pagination ─────────────────────────────────────────────────────────────

  Future<void> loadNextPage() async {
    final current = state.valueOrNull;

    // guard: dont load if already loading or no more pages
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    // show loading indicator at bottom without replacing the whole state
    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    try {
      final nextPage = current.currentPage + 1;
      final newGroups = await ref
          .read(albumServiceProvider)
          .getMediaAssetsInAlbum(
            albumId: arg,
            page: nextPage,
            limit: _pageSize,
          );

      state = AsyncValue.data(
        current.copyWith(
          // merge new groups into existing, handling day boundary splits
          mediaAssets: [...current.mediaAssets, ...newGroups],
          currentPage: nextPage,
          isLoadingMore: false,
          hasMore: _countAssets(newGroups) >= _pageSize,
        ),
      );
    } catch (e, st) {
      // restore previous data, surface error separately
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
      // optionally: expose error to UI via a separate error state field
    }
  }

  // ── Selection ──────────────────────────────────────────────────────────────

  void enterSelectionMode(String firstAssetId) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(isSelectionMode: true, selectedAssetIds: {firstAssetId}),
    );
  }

  void exitSelectionMode() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(isSelectionMode: false, selectedAssetIds: {}),
    );
  }

  void toggleSelectMedia(String assetId) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = Set<String>.from(current.selectedAssetIds);
    if (updated.contains(assetId)) {
      updated.remove(assetId);
    } else {
      updated.add(assetId);
    }

    // exit selection mode automatically if nothing selected
    state = AsyncValue.data(
      current.copyWith(
        selectedAssetIds: updated,
        isSelectionMode: updated.isNotEmpty,
      ),
    );
  }

  void selectAll() {
    final current = state.valueOrNull;
    if (current == null) return;
    final allIds = current.mediaAssets.map((a) => a.assetId).toSet();
    state = AsyncValue.data(current.copyWith(selectedAssetIds: allIds));
  }

  void clearSelection() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(selectedAssetIds: {}));
  }

  // Operations

  // Future<void> moveSelectedToAlbum(String targetAlbumId) async {
  //   final current = state.valueOrNull;
  //   if (current == null || current.selectedAssetIds.isEmpty) return;

  //   final assetIds = List<String>.from(current.selectedAssetIds);

  //   await ref
  //       .read(albumServiceProvider)
  //       .moveAssetsToAlbum(targetAlbumId, assetIds);

  //   // optimistically remove moved assets from the current view
  //   state = AsyncValue.data(
  //     current.copyWith(
  //       mediaAssets: _removeAssets(
  //         current.mediaAssets,
  //         current.selectedAssetIds,
  //       ),
  //       selectedAssetIds: {},
  //       isSelectionMode: false,
  //     ),
  //   );
  // }

  // Future<void> moveSelectedToTrash() async {
  //   final current = state.valueOrNull;
  //   if (current == null || current.selectedAssetIds.isEmpty) return;

  //   await ref.read(trashServiceProvider).moveToTrash(current.selectedAssets);

  //   state = AsyncValue.data(
  //     current.copyWith(
  //       mediaAssets: _removeAssets(
  //         current.mediaAssets,
  //         current.selectedAssetIds,
  //       ),
  //       selectedAssetIds: {},
  //       isSelectionMode: false,
  //     ),
  //   );
  // }

  // Helpers

  /// Merges incoming page groups into existing groups.
  /// Handles the case where a page boundary splits a single day.
  // List<DailyMediaGroup> _mergeGroups(
  //   List<DailyMediaGroup> existing,
  //   List<DailyMediaGroup> incoming,
  // ) {
  //   if (incoming.isEmpty) return existing;
  //   final result = List<DailyMediaGroup>.from(existing);

  //   for (final incomingGroup in incoming) {
  //     final last = result.isNotEmpty ? result.last : null;
  //     if (last != null &&
  //         _isSameDay(last.captureDate, incomingGroup.captureDate)) {
  //       // same day straddles the page boundary — merge into last group
  //       result[result.length - 1] = DailyMediaGroup(
  //         captureDate: last.captureDate,
  //         mediaAssets: [...last.mediaAssets, ...incomingGroup.mediaAssets],
  //       );
  //     } else {
  //       result.add(incomingGroup);
  //     }
  //   }
  //   return result;
  // }

  /// Removes assets by id from all groups, drops empty groups afterward.
  // List<DailyMediaGroup> _removeAssets(
  //   List<DailyMediaGroup> groups,
  //   Set<String> assetIds,
  // ) {
  //   return groups
  //       .map(
  //         (g) => DailyMediaGroup(
  //           captureDate: g.captureDate,
  //           mediaAssets: g.mediaAssets
  //               .where((a) => !assetIds.contains(a.assetId))
  //               .toList(),
  //         ),
  //       )
  //       .where((g) => g.mediaAssets.isNotEmpty)
  //       .toList();
  // }

  int _countAssets(List<MediaAsset> mediaAssets) => mediaAssets.length;

  // bool _isSameDay(DateTime a, DateTime b) =>
  //     a.year == b.year && a.month == b.month && a.day == b.day;
}

final albumDetailControllerProvider = AsyncNotifierProvider.autoDispose
    .family<AlbumDetailController, AlbumDetailState, String>(
      AlbumDetailController.new,
    );
