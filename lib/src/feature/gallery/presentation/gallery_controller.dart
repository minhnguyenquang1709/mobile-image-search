import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/feature/gallery/application/gallery_service.dart';
import 'package:mobile_image_search/src/feature/gallery/application/trash_service.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:photo_manager/photo_manager.dart';

@immutable
class GalleryState {
  final List<DailyMediaGroup> mediaGroups;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final bool isSelectionMode;
  final Set<String> selectedAssetIds;

  const GalleryState({
    required this.mediaGroups,
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.isSelectionMode = false,
    this.selectedAssetIds = const {},
  });

  GalleryState copyWith({
    List<DailyMediaGroup>? mediaGroups,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    bool? isSelectionMode,
    Set<String>? selectedAssetIds,
  }) {
    return GalleryState(
      mediaGroups: mediaGroups ?? this.mediaGroups,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedAssetIds: selectedAssetIds ?? this.selectedAssetIds,
    );
  }
}

/// Behave like ViewModel in MVVM
///
/// State Controller
///
/// Data caching
class GalleryController extends AutoDisposeAsyncNotifier<GalleryState> {
  static const int _pageSize = 100;

  @override
  FutureOr<GalleryState> build() async {
    _init();

    ref.onDispose(_dispose);

    final hasPermission = await ref
        .read(galleryServiceProvider)
        .requestGalleryAccess();

    if (!hasPermission) {
      throw Exception('Gallery access permission denied');
    }
    final newImages = await _fetchPage(0);
    final groups = groupMediaByDate(newImages);

    return GalleryState(
      mediaGroups: groups,
      hasMore: _countAssets(newImages) >= _pageSize,
      currentPage: 0,
    );
  }

  /// Refresh gallery when change detected
  ///
  /// Fire and forget
  Future<void> _refresh(MethodCall call) async {
    // _logger.printLog("\nGallery change detected: ${call.method}\n"); // android: "change"

    final current = state.valueOrNull;
    final refetchPages = current?.currentPage ?? 0;

    state = const AsyncValue.data(GalleryState(mediaGroups: []));

    final firstPage = await _fetchPage(0);
    final firstGroups = groupMediaByDate(firstPage);

    state = AsyncValue.data(
      GalleryState(
        mediaGroups: firstGroups,
        hasMore: _countAssets(firstPage) >= _pageSize,
        currentPage: 0,
      ),
    );

    for (var i = 0; i < refetchPages; i++) {
      await loadMore();
    }
  }

  void _init() {
    PhotoManager.addChangeCallback(_refresh);

    PhotoManager.startChangeNotify();
  }

  void _dispose() {
    PhotoManager.removeChangeCallback(_refresh);

    PhotoManager.stopChangeNotify();
  }

  /// Group images
  List<DailyMediaGroup> groupMediaByDate(List<MediaAsset> media) {
    final Map<DateTime, List<MediaAsset>> groupedMap = {};

    for (var mediaItem in media) {
      final DateTime dateTime = mediaItem.createDateTime;

      // normalize to date
      final DateTime dateObj = DateTime(
        dateTime.year,
        dateTime.month,
        dateTime.day,
      );

      if (!groupedMap.containsKey(dateObj)) {
        groupedMap[dateObj] = [];
      }
      groupedMap[dateObj]!.add(mediaItem);
    }

    final List<DailyMediaGroup> groups = groupedMap.entries.map((entry) {
      return DailyMediaGroup(datetime: entry.key, mediaAssets: entry.value);
    }).toList();

    return groups;
  }

  Future<List<MediaAsset>> _fetchPage(int page) async {
    final galleryService = ref.read(galleryServiceProvider);

    final List<MediaAsset> newMediaItems = await galleryService.readGallery(
      page: page,
      limit: _pageSize,
    );

    // cache
    // for (final media in newMediaItems) {
    //   _cachedMediaItems[media.assetId] = media;
    // }

    return newMediaItems;
  }

  /// Fetch next page
  ///
  /// Merge with cached image groups
  Future<void> loadMore() async {
    final current = state.valueOrNull;

    if (current == null || current.isLoading || !current.hasMore) return;

    state = AsyncValue.data(current.copyWith(isLoading: true));

    try {
      final nextPage = current.currentPage + 1;
      final newImages = await _fetchPage(nextPage);

      if (newImages.isEmpty) {
        state = AsyncValue.data(
          current.copyWith(isLoading: false, hasMore: false),
        );
        return;
      }

      final newImageGroups = groupMediaByDate(newImages);
      final mergedGroups = _mergeGroups(current.mediaGroups, newImageGroups);

      state = AsyncValue.data(
        current.copyWith(
          mediaGroups: mergedGroups,
          currentPage: nextPage,
          isLoading: false,
          hasMore: _countAssets(newImages) >= _pageSize,
        ),
      );
    } catch (e) {
      state = AsyncValue.data(current.copyWith(isLoading: false));
    }
  }

  bool _isSameDay(DateTime dateA, DateTime dateB) {
    return dateA.year == dateB.year &&
        dateA.month == dateB.month &&
        dateA.day == dateB.day;
  }

  List<DailyMediaGroup> _mergeGroups(
    List<DailyMediaGroup> existing,
    List<DailyMediaGroup> incoming,
  ) {
    if (existing.isEmpty) return incoming;
    if (incoming.isEmpty) return existing;

    final lastExisting = existing.last;
    final firstIncoming = incoming.first;

    if (_isSameDay(lastExisting.datetime, firstIncoming.datetime)) {
      final mergedGroup = DailyMediaGroup(
        datetime: lastExisting.datetime,
        mediaAssets: [
          ...lastExisting.mediaAssets,
          ...firstIncoming.mediaAssets,
        ],
      );

      return [
        ...existing.sublist(0, existing.length - 1),
        mergedGroup,
        ...incoming.sublist(1),
      ];
    }

    return [...existing, ...incoming];
  }

  void toggleSelectMedia(String assetId) {
    final current = state.valueOrNull;
    if (current == null) return;

    // create new set
    final updatedSelectedIds = Set<String>.from(current.selectedAssetIds);
    if (updatedSelectedIds.contains(assetId)) {
      updatedSelectedIds.remove(assetId);
    } else {
      updatedSelectedIds.add(assetId);
    }

    state = AsyncValue.data(
      current.copyWith(
        selectedAssetIds: updatedSelectedIds,
        isSelectionMode: updatedSelectedIds.isNotEmpty,
      ),
    );
  }

  /// print metadata of image
  Future<void> printImageMetadata(String assetId) async {
    // final galleryService = ref.read(galleryServiceProvider);
    // await galleryService.getImageMetadata(assetId);
  }

  Future<void> requestGalleryAccess() async {
    final galleryService = ref.read(galleryServiceProvider);
    await galleryService.requestGalleryAccess();
  }

  Future<void> createAlbum(String albumName) async {
    // final galleryService = ref.read(galleryServiceProvider);
    // await galleryService.createAlbum(albumName, _testMediaAssetsToMoveToAlbum);
  }

  Future<void> moveSelectedToTrash() async {
    final current = state.valueOrNull;
    if (current == null || current.selectedAssetIds.isEmpty) return;

    final selectedMediaAssets = current.mediaGroups
        .expand((g) => g.mediaAssets)
        .where((a) => current.selectedAssetIds.contains(a.assetId))
        .toList();
    final trashService = ref.read(trashServiceProvider);
    await trashService.moveToTrash(selectedMediaAssets);
  }

  void moveMediaToAlbum() {
    // final galleryService = ref.read(galleryServiceProvider);
    // final String opId = galleryService.newOperationId;
    // galleryService.moveMediaToAlbum(opId: opId);
  }

  int _countAssets(List<MediaAsset> mediaAssets) => mediaAssets.length;
}

final galleryControllerProvider =
    AsyncNotifierProvider.autoDispose<GalleryController, GalleryState>(
      GalleryController.new,
    );
