import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/constants/common_constant.dart';
import 'package:mobile_image_search/src/feature/indexing/application/indexing_service.dart';
import 'package:mobile_image_search/src/feature/gallery/application/gallery_service.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
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

  // TODO: remove this debug
  // to test creating album
  final List<MediaAsset> _testMediaAssetsToMoveToAlbum = [
    MediaAsset(
      assetId: "1000058150",
      title: "",
      createDateTime: DateTime.now(),
      modifiedDateTime: DateTime.now(),
      mediaType: EMediaType.image,
    ),
    MediaAsset(
      assetId: "1000058152",
      title: "",
      createDateTime: DateTime.now(),
      modifiedDateTime: DateTime.now(),
      mediaType: EMediaType.image,
    ),
    MediaAsset(
      assetId: "1000058155",
      title: "",
      createDateTime: DateTime.now(),
      modifiedDateTime: DateTime.now(),
      mediaType: EMediaType.image,
    ),
  ];

  final List<MediaAsset> _testMediaAssetsToThrowToTrash = [
    MediaAsset(
      assetId: "1000058148",
      title: "",
      createDateTime: DateTime.now(),
      modifiedDateTime: DateTime.now(),
      mediaType: EMediaType.image,
    ),
    MediaAsset(
      assetId: "1000058149",
      title: "",
      createDateTime: DateTime.now(),
      modifiedDateTime: DateTime.now(),
      mediaType: EMediaType.image,
    ),
    MediaAsset(
      assetId: "1000058150",
      title: "",
      createDateTime: DateTime.now(),
      modifiedDateTime: DateTime.now(),
      mediaType: EMediaType.image,
    ),
    MediaAsset(
      assetId: "1000058152",
      title: "",
      createDateTime: DateTime.now(),
      modifiedDateTime: DateTime.now(),
      mediaType: EMediaType.image,
    ),
    MediaAsset(
      assetId: "1000058155",
      title: "",
      createDateTime: DateTime.now(),
      modifiedDateTime: DateTime.now(),
      mediaType: EMediaType.image,
    ),
  ];

  // final Map<String, MediaAsset> _cachedMediaItems = {};

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

    return groupImagesByDate(newImages);
  }

  /// Refresh gallery when change detected
  ///
  /// Fire and forget
  Future<void> _refresh(MethodCall call) async {
    // _logger.printLog("\nGallery change detected: ${call.method}\n"); // android: "change"

    // clear old state
    state = AsyncValue.data([]);
    // _cachedMediaItems.clear();

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
  List<MediaGroup> groupImagesByDate(List<MediaAsset> media) {
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

    final List<MediaGroup> groups = groupedMap.entries.map((entry) {
      return MediaGroup(date: entry.key, mediaItems: entry.value);
    }).toList();

    return groups;
  }

  Future<List<MediaAsset>> _fetchPage(int page) async {
    final galleryService = ref.read(galleryServiceProvider);

    final List<MediaAsset> newMediaItems = await galleryService.readGallery(
      page: page,
      limit: _limit,
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
    // final galleryService = ref.read(galleryServiceProvider);
    // await galleryService.getImageMetadata(assetId);
  }

  Future<void> requestGalleryAccess() async {
    final galleryService = ref.read(galleryServiceProvider);
    await galleryService.requestGalleryAccess();
  }

  Future<void> createAlbum(String albumName) async {
    final galleryService = ref.read(galleryServiceProvider);
    await galleryService.createAlbum(albumName, _testMediaAssetsToMoveToAlbum);
  }

  Future<void> moveToTrash() async {
    final galleryService = ref.read(galleryServiceProvider);
    await galleryService.moveToTrash(_testMediaAssetsToThrowToTrash);
  }

  void moveMediaToAlbum() {
    final galleryService = ref.read(galleryServiceProvider);
    final String opId = galleryService.newOperationId;
    galleryService.moveMediaToAlbum(opId: opId);
  }
}

final galleryControllerProvider =
    AsyncNotifierProvider<GalleryController, List<MediaGroup>>(() {
      return GalleryController();
    });
