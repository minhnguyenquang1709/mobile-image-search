import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_image_search/src/data/interfaces/media_asset_repository_interface.dart';
import 'package:mobile_image_search/src/service_locator.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:photo_manager/photo_manager.dart';

/// ViewModel for Gallery Screen
class GalleryViewModel extends ChangeNotifier {
  final IMediaAssetRepository _mediaAssetRepo;

  GalleryViewModel({required IMediaAssetRepository mediaAssetRepo})
    : _mediaAssetRepo = mediaAssetRepo {
    _init();
  }

  static const int _pageSize = 100;

  // State Variables
  // gallery data
  final List<MediaAsset> _allMediaAssets = [];
  bool isLoading = false;
  bool hasMore = true;
  int _currentPage = 0;

  bool permissionDenied = false;

  bool _indexingStarted = false;

  List<MediaAsset> get mediaAssets => List.unmodifiable(_allMediaAssets);

  // Initialization
  void _init() {
    PhotoManager.addChangeCallback(_onPhotoManagerChange);
    PhotoManager.startChangeNotify();
  }

  @override
  void dispose() {
    PhotoManager.removeChangeCallback(_onPhotoManagerChange);
    PhotoManager.stopChangeNotify();
    super.dispose();
  }

  //  Refresh callback from PhotoManager
  Future<void> _onPhotoManagerChange(MethodCall call) async {
    debugPrint("[GalleryViewModel] Device gallery changed, reloading...");
    _currentPage = 0;
    _allMediaAssets.clear();
    hasMore = true;
    notifyListeners();
    await loadInitial();
  }

  //  Actions
  Future<void> loadInitial() async {
    if (isLoading) return;

    isLoading = true;
    notifyListeners();

    try {
      final hasPermission = await _mediaAssetRepo.requestGalleryAccess();
      if (!hasPermission) {
        permissionDenied = true;
        return;
      }
      permissionDenied = false;

      final newImages = await _mediaAssetRepo.fetchPage(
        page: 0,
        pageSize: _pageSize,
      );

      _allMediaAssets.clear();
      _allMediaAssets.addAll(newImages);
      _currentPage = 0;
      hasMore = newImages.length >= _pageSize;

      debugPrint(
        "[GalleryViewModel] Initial load complete: ${_allMediaAssets.length} images",
      );

      if (!_indexingStarted) {
        _indexingStarted = true;
        ServiceLocator.indexingService.indexGallery();
      }
    } catch (e) {
      debugPrint("[GalleryViewModel] Error loading gallery: $e");
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (isLoading || !hasMore) return;

    isLoading = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final newImages = await _mediaAssetRepo.fetchPage(
        page: nextPage,
        pageSize: _pageSize,
      );

      if (newImages.isEmpty) {
        hasMore = false;
      } else {
        _allMediaAssets.addAll(newImages);
        _currentPage = nextPage;
        hasMore = newImages.length >= _pageSize;
        debugPrint(
          "[GalleryViewModel] Page $nextPage loaded: ${newImages.length} new images",
        );
      }
    } catch (e) {
      debugPrint("[GalleryViewModel] Error loading more: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  ImageProvider thumbnailProviderFor(String assetId) {
    return _mediaAssetRepo.thumbnailProviderFor(assetId);
  }
}
