import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/utils/logger.dart';
import 'package:mobile_image_search/src/feature/gallery/application/gallery_service.dart';
import 'package:mobile_image_search/src/shared/domain/model/media.dart';
import 'package:photo_manager/photo_manager.dart';

/// Behave like ViewModel in MVVM
///
/// State Controller
///
/// Data caching
class GalleryController extends AsyncNotifier<List<MediaGroup>> {
  int _currentPage = 0;
  final int _limit = 100;
  bool _isFetching = false; // prevent spam
  bool _hasReachedEnd = false; // end of gallery

  final Map<String, Media> _cachedMediaItems = {};

  final Logger _logger = loggers[LoggerName.galleryController]!;

  @override
  Future<List<MediaGroup>> build() async {
    _init();

    ref.onDispose(_dispose);

    final hasPermission = await ref
        .read(galleryServiceProvider)
        .requestGalleryAccess();

    if (!hasPermission) {
      throw Exception('Gallery access permission denied');
    }
    final newImages = await _fetchPage(_currentPage);

    // TODO: remove debug
    _logger.printLog("Fire and forget fetching all metadata...");
    final galleryService = ref.read(galleryServiceProvider);
    galleryService.getAllMetadata();
    _logger.printLog("All media metadata fetching called!");

    return groupImagesByDate(newImages);
  }

  /// Refresh gallery when change detected
  ///
  /// Fire and forget
  Future<void> _refresh(MethodCall call) async {
    // _logger.printLog("\nGallery change detected: ${call.method}\n"); // android: "change"

    // clear old state
    state = AsyncValue.data([]);
    _cachedMediaItems.clear();

    // refresh
    int refetchPages = _currentPage;
    _currentPage = 0;
    do {
      await loadMore();
    } while (_currentPage < refetchPages);
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
  List<MediaGroup> groupImagesByDate(List<Media> media) {
    final Map<DateTime, List<Media>> groupedMap = {};

    for (var mediaItem in media) {
      final DateTime dateTime = mediaItem.metadata.createDateTime;

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

    final List<MediaGroup> groups = groupedMap.entries.map((entry) {
      return MediaGroup(date: entry.key, mediaItems: entry.value);
    }).toList();

    // groups.sort((a, b) => b.date.compareTo(a.date));

    return groups;
  }

  Future<List<Media>> _fetchPage(int page) async {
    final galleryService = ref.read(galleryServiceProvider);

    final List<Media> newMediaItems = await galleryService.readGallery(
      page: page,
      limit: _limit,
    );

    // TODO: remove debug
    // final indexingService = await ref.read(indexingServiceProvider.future);
    // final List<String> assetIds = [];
    // for (int i = 0; i < 5; i++) {
    //   assetIds.add(images[i].assetEntity.id);
    // }
    // indexingService.enQueue(assetIds);
    // indexingService.processNextTask();

    // cache
    for (final media in newMediaItems) {
      _cachedMediaItems[media.assetId] = media;
    }

    return newMediaItems;
  }

  /// Fetch next page
  ///
  /// Merge with cached image groups
  Future<void> loadMore() async {
    if (_isFetching || _hasReachedEnd) return;

    _isFetching = true;

    try {
      final nextPage = _currentPage + 1;
      final newImages = await _fetchPage(nextPage);

      if (newImages.isEmpty) {
        _hasReachedEnd = true;
      } else {
        _currentPage = nextPage;

        final currentGroups = state.value ?? [];
        final newImageGroups = groupImagesByDate(newImages);

        if (currentGroups.isEmpty) {
          state = AsyncValue.data(newImageGroups);
          return;
        }

        if (_isSameDay(currentGroups.last.date, newImageGroups.first.date)) {
          // merge with cached data
          final mergedGroup = MediaGroup(
            date: currentGroups.last.date,
            mediaItems: [
              ...currentGroups.last.mediaItems,
              ...newImageGroups.first.mediaItems,
            ],
          );
          state = AsyncValue.data([
            ...currentGroups.sublist(0, currentGroups.length - 1),
            mergedGroup,
            ...newImageGroups.sublist(1),
          ]);
        } else {
          // just append
          state = AsyncValue.data([...currentGroups, ...newImageGroups]);
        }
      }
    } catch (e, _) {
      _logger.printLog("\nError fetching page $_currentPage: $e\n");
    } finally {
      _isFetching = false;
    }
  }

  bool _isSameDay(DateTime dateA, DateTime dateB) {
    return dateA.year == dateB.year &&
        dateA.month == dateB.month &&
        dateA.day == dateB.day;
  }

  /// print metadata of image
  Future<void> printImageMetadata(String assetId) async {
    final galleryService = ref.read(galleryServiceProvider);
    await galleryService.getImageMetadata(assetId);
  }

  Future<void> requestGalleryAccess() async {
    final galleryService = ref.read(galleryServiceProvider);
    await galleryService.requestGalleryAccess();
  }
}

final galleryControllerProvider =
    AsyncNotifierProvider<GalleryController, List<MediaGroup>>(() {
      return GalleryController();
    });
