import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobile_image_search/objectbox.g.dart';
import 'package:mobile_image_search/src/feature/gallery/application/trash_service.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/trash_view_model.dart';
import 'package:mobile_image_search/src/feature/indexing/data/background_worker_data_source.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_image_embedding.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_repository.dart';
import 'package:mobile_image_search/src/feature/search/application/image_search_service.dart';
import 'package:mobile_image_search/src/feature/search/domain/model/search_result.dart';
import 'package:mobile_image_search/src/service_locator.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:mobile_image_search/src/utils/media_processing.dart';
import 'package:objectbox/objectbox.dart';
import 'package:photo_manager/photo_manager.dart';

/// ViewModel for Gallery Screen
class GalleryViewModel extends ChangeNotifier {
  static final GalleryViewModel instance = GalleryViewModel._internal();
  GalleryViewModel._internal() {
    _init();
  }

  static const int _pageSize = 100;

  final TrashService _trashService = ServiceLocator.trashService;
  final ObjectBoxClient _objectBoxClient = ServiceLocator.objectBoxClient;
  final BackgroundWorkerDataSource _bgWorkerClient =
      ServiceLocator.backgroundWorkerDataSource;

  // State Variables
  // gallery data
  final List<MediaAsset> _allMediaAssets = [];
  bool isLoading = false;
  bool hasMore = true;
  int _currentPage = 0;
  final Set<String> _selectedAssetIds = {};
  // search data
  String currentSearchQuery = "";
  bool _isSearchModeOn = false;
  bool get isSearchModeOn => _isSearchModeOn;
  final List<MediaAsset> _searchResults = [];
  List<MediaAsset> get searchResults => List.unmodifiable(_searchResults);

  List<MediaAsset> get mediaAssets => List.unmodifiable(_allMediaAssets);
  Set<String> get selectedAssetIds => Set.unmodifiable(_selectedAssetIds);
  bool get isSelectionMode => _selectedAssetIds.isNotEmpty;

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
      hasMore = newImages.length >= _pageSize;

      debugPrint(
        "[GalleryViewModel] Initial load complete: ${_allMediaAssets.length} images",
      );
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
      final galleryService = ServiceLocator.galleryService;
      final nextPage = _currentPage + 1;
      final newImages = await galleryService.readGallery(
        page: nextPage,
        limit: _pageSize,
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

    debugPrint(
      "[GalleryViewModel] Moving ${_selectedAssetIds.length} items to trash",
    );

    // find the full MediaAsset objects for selected IDs
    final selectedMediaAssets = _allMediaAssets
        .where((a) => _selectedAssetIds.contains(a.assetId))
        .toList();

    if (selectedMediaAssets.isEmpty) return;

    // call the service to move to trash
    try {
      await _trashService.moveToTrash(selectedMediaAssets);
      debugPrint("[GalleryViewModel] Successfully moved items to trash");

      // update the TrashViewModel state to hide items from gallery and show in trash
      TrashViewModel.instance.markAsTrashed(_selectedAssetIds.toList());
    } catch (e) {
      debugPrint("[GalleryViewModel] Error moving to trash: $e");
      rethrow;
    }

    // clear selection
    _selectedAssetIds.clear();
    notifyListeners();
  }

  void clearSearch() {
    currentSearchQuery = "";
    _searchResults.clear();
    _isSearchModeOn = false;
    notifyListeners();
  }

  /// Search by an English phrase
  Future<void> searchByPhrase(String textQuery) async {
    debugPrint("[GalleryViewModel] Starting search for query: '$textQuery'");
    if (textQuery.trim().isEmpty) {
      throw Exception("Search query cannot be empty");
    }

    currentSearchQuery = textQuery;
    _searchResults.clear();
    _isSearchModeOn = true;
    notifyListeners();

    // generate embedding for text query
    final queryVector = await _bgWorkerClient.encodeText(textQuery);

    final Box<ObjectBoxImageEmbedding> imageEmbeddingBox = _objectBoxClient
        .store
        .box<ObjectBoxImageEmbedding>();

    // get semantic search results
    final searchQuery = imageEmbeddingBox
        .query(
          ObjectBoxImageEmbedding_.embedding.nearestNeighborsF32(
            queryVector,
            100,
          ),
        )
        .build();
    final searchResults = await searchQuery.findWithScoresAsync();

    debugPrint(
      "[GalleryViewModel] Search completed with ${searchResults.length} results",
    );

    final domainResults = searchResults.map((result) {
      return SearchResultMatch(
        assetId: result.object.assetId,
        cosineScore: result.score,
      );
    }).toList();

    // debug: print to terminal
    for (var i = 0; i < domainResults.length; i++) {
      debugPrint(
        "[GalleryViewModel] Result ${i + 1}: assetId=${domainResults[i].assetId}, cosineScore=${domainResults[i].cosineScore}",
      );
    }

    for (final result in domainResults) {
      final AssetEntity? asset = await AssetEntity.fromId(result.assetId);
      if (asset == null) {
        // print error
        debugPrint(
          "[GalleryViewModel] Warning: photo_manager cannot find asset with ID ${result.assetId}",
        );
        continue;
      }
      final MediaAsset mediaAsset = toMediaAsset(asset);
      _searchResults.add(mediaAsset);
    }

    notifyListeners();
  }
}
