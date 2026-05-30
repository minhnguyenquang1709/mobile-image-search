import 'package:flutter/foundation.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/trash_view_model.dart';
import 'package:mobile_image_search/src/service_locator.dart';
import 'package:mobile_image_search/src/shared/domain/model/album.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

/// ViewModel for Albums
///
/// Maintains state for the global album list and the currently opened album details
class AlbumViewModel extends ChangeNotifier {
  static final AlbumViewModel instance = AlbumViewModel._internal();

  AlbumViewModel._internal();

  static const int _pageSize = 40;

  final List<Album> _albums = [];
  bool _isLoadingAlbums = false;

  List<Album> get albums => List.unmodifiable(_albums);
  bool get isLoadingAlbums => _isLoadingAlbums;

  String? _currentAlbumId;
  final List<MediaAsset> _currentAlbumAssets = [];
  bool _isLoadingAssets = false;
  bool _hasMoreAssets = true;
  int _currentPage = 0;
  final Set<String> _selectedAssetIds = {};

  String? get currentAlbumId => _currentAlbumId;
  List<MediaAsset> get currentAlbumAssets =>
      List.unmodifiable(_currentAlbumAssets);
  bool get isLoadingAssets => _isLoadingAssets;
  bool get hasMoreAssets => _hasMoreAssets;
  Set<String> get selectedAssetIds => Set.unmodifiable(_selectedAssetIds);
  bool get isSelectionMode => _selectedAssetIds.isNotEmpty;

  Future<void> loadAlbums() async {
    if (_isLoadingAlbums) return;

    _isLoadingAlbums = true;
    notifyListeners();

    try {
      final result = await ServiceLocator.albumService.getAlbums();
      _albums.clear();
      _albums.addAll(result);
      _albums.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    } catch (e) {
      debugPrint("[AlbumViewModel] Error loading albums: $e");
    } finally {
      _isLoadingAlbums = false;
      notifyListeners();
    }
  }

  Future<void> loadAlbumDetailsInitial(String albumId) async {
    _currentAlbumId = albumId;
    _currentPage = 0;
    _hasMoreAssets = true;
    _currentAlbumAssets.clear();
    _selectedAssetIds.clear();
    _isLoadingAssets = true;
    notifyListeners();

    try {
      final result = await ServiceLocator.albumService.getMediaAssetsInAlbum(
        albumId: albumId,
        page: _currentPage,
        limit: _pageSize,
      );
      _currentAlbumAssets.addAll(result);
      _hasMoreAssets = result.length >= _pageSize;
    } catch (e) {
      debugPrint("[AlbumViewModel] Error loading initial album details: $e");
    } finally {
      _isLoadingAssets = false;
      notifyListeners();
    }
  }

  Future<void> loadAlbumDetailsNextPage() async {
    if (_isLoadingAssets || !_hasMoreAssets || _currentAlbumId == null) return;

    _isLoadingAssets = true;
    notifyListeners(); // Optionally notify to show the trailing loading indicator

    try {
      final nextPage = _currentPage + 1;
      final result = await ServiceLocator.albumService.getMediaAssetsInAlbum(
        albumId: _currentAlbumId!,
        page: nextPage,
        limit: _pageSize,
      );

      if (result.isEmpty) {
        _hasMoreAssets = false;
      } else {
        _currentAlbumAssets.addAll(result);
        _currentPage = nextPage;
        _hasMoreAssets = result.length >= _pageSize;
      }
    } catch (e) {
      debugPrint(
        "[AlbumViewModel] Error loading next page of album details: $e",
      );
    } finally {
      _isLoadingAssets = false;
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

  void selectAll() {
    _selectedAssetIds.clear();
    _selectedAssetIds.addAll(_currentAlbumAssets.map((a) => a.assetId));
    notifyListeners();
  }

  void clearSelection() {
    _selectedAssetIds.clear();
    notifyListeners();
  }

  Future<void> moveSelectedToTrash() async {
    if (_selectedAssetIds.isEmpty) return;

    debugPrint(
      "[AlbumViewModel] Moving ${_selectedAssetIds.length} items to trash",
    );

    // find the full MediaAsset objects for selected IDs
    final selectedMediaAssets = _currentAlbumAssets
        .where((a) => _selectedAssetIds.contains(a.assetId))
        .toList();

    if (selectedMediaAssets.isEmpty) return;

    // call the service to move to trash
    try {
      await ServiceLocator.trashService.moveToTrash(selectedMediaAssets);
      debugPrint("[AlbumViewModel] Successfully moved items to trash");

      // update the TrashViewModel state
      TrashViewModel.instance.markAsTrashed(_selectedAssetIds.toList());
    } catch (e) {
      debugPrint("[AlbumViewModel] Error moving to trash: $e");
      rethrow;
    }

    // clear selection
    _selectedAssetIds.clear();
    notifyListeners();
  }

  // album creation
  /// Creates a new album with the given name.
  /// This create a record in database.
  Future<void> createAlbum(String albumName, [String? description]) async {
    try {
      final newAlbum = await ServiceLocator.albumService.createAlbum(
        albumName,
        description,
      );
      _albums.add(newAlbum);
      notifyListeners();
      debugPrint("[AlbumViewModel] Created new album: ${newAlbum.title}");
    } catch (e) {
      debugPrint("[AlbumViewModel] Error creating album: $e");
    }
  }

  Future<void> deleteAlbum(String albumId, {bool deleteAssets = false}) async {
    try {
      await ServiceLocator.albumService.deleteAlbum(
        albumId,
        deleteAssets: deleteAssets,
      );
      // reload albums list after deletion
      await loadAlbums();
    } catch (e) {
      debugPrint("[AlbumViewModel] Error deleting album: $e");
      rethrow;
    }
  }
}
