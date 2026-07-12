import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_image_search/src/data/interfaces/media_asset_repository_interface.dart';
import 'package:mobile_image_search/src/feature/gallery/domain/album_form_validator.dart';
import 'package:mobile_image_search/src/service_locator.dart';
import 'package:mobile_image_search/src/shared/domain/interface/album_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/album.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:mobile_image_search/src/shared/domain/model/move_progress.dart';

/// ViewModel for Albums
///
/// Maintains state for the global album list and the currently opened album details
class AlbumViewModel extends ChangeNotifier {
  final IAlbumRepository _albumRepo;
  final IMediaAssetRepository _mediaAssetRepo;
  final AlbumFormValidator _albumFormValidator;

  AlbumViewModel({
    required IAlbumRepository albumRepo,
    required IMediaAssetRepository mediaAssetRepo,
    required AlbumFormValidator albumFormValidator,
  }) : _albumRepo = albumRepo,
       _mediaAssetRepo = mediaAssetRepo,
       _albumFormValidator = albumFormValidator;

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

  String? get currentAlbumId => _currentAlbumId;
  List<MediaAsset> get currentAlbumAssets =>
      List.unmodifiable(_currentAlbumAssets);
  bool get isLoadingAssets => _isLoadingAssets;
  bool get hasMoreAssets => _hasMoreAssets;

  MoveProgress _moveProgress = MoveProgress.idle();
  MoveProgress get moveProgress => _moveProgress;

  Future<void> loadAlbums() async {
    if (_isLoadingAlbums) return;

    _isLoadingAlbums = true;
    notifyListeners();

    try {
      final result = await _albumRepo.getAlbums();
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
    _isLoadingAssets = true;
    notifyListeners();

    try {
      final result = await _mediaAssetRepo.fetchAlbumPage(
        albumId: albumId,
        page: _currentPage,
        pageSize: _pageSize,
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
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final result = await _mediaAssetRepo.fetchAlbumPage(
        albumId: _currentAlbumId!,
        page: nextPage,
        pageSize: _pageSize,
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

  Future<Album> createAlbum(String albumName, [String? description]) async {
    _albumFormValidator.validate(albumName, description);

    final newAlbum = await _albumRepo.createAlbum(
      albumName.trim(),
      description,
    );
    _albums.add(newAlbum);
    _albums.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    notifyListeners();
    debugPrint("[AlbumViewModel] Created new album: ${newAlbum.title}");
    return newAlbum;
  }

  Future<void> deleteAlbum(String albumId, {bool deleteAssets = false}) async {
    try {
      await _albumRepo.deleteAlbum(albumId, deleteAssets: deleteAssets);
      // reload album list
      await loadAlbums();
    } catch (e) {
      debugPrint("[AlbumViewModel] Error deleting album: $e");
      rethrow;
    }
  }

  Future<void> moveAssetsToAlbum(Album album, List<MediaAsset> assets) async {
    if (assets.isEmpty) return;

    final stream = _albumRepo.moveAssetsToAlbum(album, assets);

    await for (final progress in stream) {
      _moveProgress = progress;
      notifyListeners();

      if (progress.state == MoveState.done) {
        await loadAlbums();
        await ServiceLocator.indexingService.indexGallery();
      }
    }

    _moveProgress = MoveProgress.idle();
    notifyListeners();
  }

  /// Drop the given assets from the opened album after they were permanently deleted from the device.
  void removeAssets(Iterable<String> assetIds) {
    final Set<String> ids = assetIds.toSet();
    if (ids.isEmpty) return;

    final int before = _currentAlbumAssets.length;
    _currentAlbumAssets.removeWhere((a) => ids.contains(a.assetId));
    if (_currentAlbumAssets.length != before) {
      notifyListeners();
    }
  }

  ImageProvider thumbnailProviderFor(String assetId) {
    return _mediaAssetRepo.thumbnailProviderFor(assetId);
  }
}
