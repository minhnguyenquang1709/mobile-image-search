import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/core/utils/logger.dart';
import 'package:mobile_image_search/feature/gallery/application/gallery_service.dart';
import 'package:mobile_image_search/shared/domain/image_model.dart';

/// Behave like ViewModel in MVVM
///
/// State Controller
class GalleryController extends AsyncNotifier<List<ImageGroup>> {
  int _currentPage = 0;
  final int _limit = 100;
  bool _isFetching = false; // prevent spam
  bool _hasReachedEnd = false; // end of gallery

  List<ImageGroup> _cachedImageGroups = [];

  final Logger _logger = loggers[LoggerName.galleryController]!;

  @override
  Future<List<ImageGroup>> build() async {
    final hasPermission = await ref
        .read(galleryServiceProvider)
        .requestGalleryAccess();
    if (!hasPermission) {
      throw Exception('Gallery access permission denied');
    }
    final newImages = await _fetchPage(_currentPage);

    return groupImagesByDate(newImages);
  }

  /// Group images
  List<ImageGroup> groupImagesByDate(List<Image> images) {
    final Map<DateTime, List<Image>> groupedMap = {};

    for (var image in images) {
      final asset = image.assetEntity;

      // final DateTime dateTime =
      //     (asset.modifiedDateSecond != null && asset.modifiedDateSecond! > 0)
      //     ? asset.modifiedDateTime
      //     : asset.createDateTime;

      final DateTime dateTime = asset.createDateTime;

      // normalize to date
      final DateTime dateObj = DateTime(
        dateTime.year,
        dateTime.month,
        dateTime.day,
      );

      if (!groupedMap.containsKey(dateObj)) {
        groupedMap[dateObj] = [];
      }
      groupedMap[dateObj]!.add(image);
    }

    final List<ImageGroup> groups = groupedMap.entries.map((entry) {
      return ImageGroup(date: entry.key, images: entry.value);
    }).toList();

    // groups.sort((a, b) => b.date.compareTo(a.date));

    return groups;
  }

  Future<List<Image>> _fetchPage(int page) async {
    final galleryService = ref.read(galleryServiceProvider);
    return await galleryService.readGallery(page: page, limit: _limit);
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
          final mergedGroup = ImageGroup(
            date: currentGroups.last.date,
            images: [
              ...currentGroups.last.images,
              ...newImageGroups.first.images,
            ],
          );
          state = AsyncValue.data([
            ...currentGroups.sublist(0, currentGroups.length - 1),
            mergedGroup,
            ...newImageGroups.sublist(1),
          ]);
        } else {
          // just append
          currentGroups.addAll(newImageGroups);
          state = AsyncValue.data(currentGroups);
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
    AsyncNotifierProvider<GalleryController, List<ImageGroup>>(() {
      return GalleryController();
    });
