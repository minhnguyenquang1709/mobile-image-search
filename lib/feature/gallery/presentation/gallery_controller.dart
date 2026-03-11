import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/core/utils/logger.dart';
import 'package:mobile_image_search/feature/gallery/application/gallery_service.dart';
import 'package:mobile_image_search/shared/domain/image_model.dart';

/// Behave like ViewModel in MVVM
///
/// State Controller
class GalleryController extends AsyncNotifier<List<Image>> {
  int _currentPage = 0;
  final int _limit = 100;
  bool _isFetching = false; // prevent spam
  bool _hasReachedEnd = false; // end of gallery

  final Logger _logger = loggers[LoggerName.galleryController]!;

  @override
  Future<List<Image>> build() async {
    return await _fetchPage(_currentPage);
  }

  Future<List<Image>> _fetchPage(int page) async {
    final galleryService = ref.read(galleryServiceProvider);
    return await galleryService.readGallery(page: page, limit: _limit);
  }

  /// fetch next page
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
        state = AsyncValue.data([...state.value!, ...newImages]);
      }
    } catch (e, st) {
      _logger.printLog("\nError fetching page $_currentPage: $e\n");
    } finally {
      _isFetching = false;
    }
  }
}

final galleryControllerProvider =
    AsyncNotifierProvider<GalleryController, List<Image>>(() {
      return GalleryController();
    });
