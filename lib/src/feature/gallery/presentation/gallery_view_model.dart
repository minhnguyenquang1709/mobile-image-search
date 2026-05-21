import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/trash_view_model.dart';
import 'package:mobile_image_search/src/service_locator.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:photo_manager/photo_manager.dart';

/// ViewModel for Gallery Screen
///
/// Responsibility: retrieve data from model, convert to a format the View can use,
/// execute logic based on user actions.
class GalleryViewModel extends ChangeNotifier {
  static final GalleryViewModel instance = GalleryViewModel._internal();
  GalleryViewModel._internal() {
    _init();
  }

  static const int _pageSize = 100;

  // --- State Variables ---
  final List<MediaAsset> _allMediaAssets = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final Set<String> _selectedAssetIds = {};

  // --- Getters ---
  List<MediaAsset> get mediaAssets => List.unmodifiable(_allMediaAssets);
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  Set<String> get selectedAssetIds => Set.unmodifiable(_selectedAssetIds);
  bool get isSelectionMode => _selectedAssetIds.isNotEmpty;

  // --- Initialization ---
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

  // --- Refresh callback from PhotoManager ---
  Future<void> _onPhotoManagerChange(MethodCall call) async {
    debugPrint("[GalleryViewModel] Device gallery changed, reloading...");
    _currentPage = 0;
    _allMediaAssets.clear();
    _hasMore = true;
    notifyListeners();
    await loadInitial();
  }

  // --- Actions ---
  Future<void> loadInitial() async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final galleryService = ServiceLocator.galleryService;
      final hasPermission = await galleryService.requestGalleryAccess();
      if (!hasPermission) {
        throw Exception('Gallery access permission denied');
      }

      final newImages = await galleryService.readGallery(
        page: 0,
        limit: _pageSize,
      );

      _allMediaAssets.clear();
      _allMediaAssets.addAll(newImages);
      _currentPage = 0;
      _hasMore = newImages.length >= _pageSize;

      debugPrint(
        "[GalleryViewModel] Initial load complete: ${_allMediaAssets.length} images",
      );
    } catch (e) {
      debugPrint("[GalleryViewModel] Error loading gallery: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final galleryService = ServiceLocator.galleryService;
      final nextPage = _currentPage + 1;
      final newImages = await galleryService.readGallery(
        page: nextPage,
        limit: _pageSize,
      );

      if (newImages.isEmpty) {
        _hasMore = false;
      } else {
        _allMediaAssets.addAll(newImages);
        _currentPage = nextPage;
        _hasMore = newImages.length >= _pageSize;
        debugPrint(
          "[GalleryViewModel] Page $nextPage loaded: ${newImages.length} new images",
        );
      }
    } catch (e) {
      debugPrint("[GalleryViewModel] Error loading more: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleSelectMedia(String assetId) {
    if (_selectedAssetIds.contains(assetId)) {
      _selectedAssetIds.remove(assetId);
    } else {
      _selectedAssetIds.add(assetId);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedAssetIds.clear();
    notifyListeners();
  }

  Future<void> moveSelectedToTrash() async {
    if (_selectedAssetIds.isEmpty) return;

    debugPrint("[GalleryViewModel] Moving ${_selectedAssetIds.length} items to trash");

    // 1. Find the full MediaAsset objects for selected IDs
    final selectedMediaAssets = _allMediaAssets
        .where((a) => _selectedAssetIds.contains(a.assetId))
        .toList();

    if (selectedMediaAssets.isEmpty) return;

    // 2. Call the service to move to trash
    try {
      await ServiceLocator.trashService.moveToTrash(selectedMediaAssets);
      debugPrint("[GalleryViewModel] Successfully moved items to trash");

      // 3. Update the TrashViewModel state to hide items from gallery and show in trash
      TrashViewModel.instance.markAsTrashed(_selectedAssetIds.toList());
    } catch (e) {
      debugPrint("[GalleryViewModel] Error moving to trash: $e");
      rethrow;
    }

    // 4. Clear selection
    _selectedAssetIds.clear();
    notifyListeners();
  }
}
