import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_image_search/src/data/interfaces/media_asset_repository_interface.dart';
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

  AlbumViewModel({
    required IAlbumRepository albumRepo,
    required IMediaAssetRepository mediaAssetRepo,
  }) : _albumRepo = albumRepo,
       _mediaAssetRepo = mediaAssetRepo;

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

  // "Move to album" progress (copy → delete-consent), surfaced to the UI.
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
    notifyListeners(); // Optionally notify to show the trailing loading indicator

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

  // album creation
  /// Creates a new album with the given name.
  /// This create a record in database.
  Future<void> createAlbum(String albumName, [String? description]) async {
    // business rule
    if (albumName.trim().isEmpty) throw Exception("Album title cannot be empty");

    try {
      final newAlbum = await _albumRepo.createAlbum(albumName, description);
      _albums.add(newAlbum);
      notifyListeners();
      debugPrint("[AlbumViewModel] Created new album: ${newAlbum.title}");
    } catch (e) {
      debugPrint("[AlbumViewModel] Error creating album: $e");
    }
  }

  Future<void> deleteAlbum(String albumId, {bool deleteAssets = false}) async {
    try {
      await _albumRepo.deleteAlbum(albumId, deleteAssets: deleteAssets);
      // reload albums list after deletion
      await loadAlbums();
    } catch (e) {
      debugPrint("[AlbumViewModel] Error deleting album: $e");
      rethrow;
    }
  }

  /// Move [assets] into [album] (copy then delete originals with consent),
  /// relaying per-file progress to the UI.
  ///
  /// On success the album list is refreshed and a re-index is triggered: the
  /// copies get NEW MediaStore ids, so their embeddings must be rebuilt
  /// (the indexing pipeline diffs device vs DB and indexes the new ids).
  Future<void> moveAssetsToAlbum(Album album, List<MediaAsset> assets) async {
    if (assets.isEmpty) return;

    final stream = _albumRepo.moveAssetsToAlbum(album, assets);

    await for (final progress in stream) {
      _moveProgress = progress;
      notifyListeners();

      if (progress.state == MoveState.done) {
        await loadAlbums();
        // copies have new asset ids → rebuild embeddings
        await ServiceLocator.indexingService.indexGallery();
      }
    }

    // reset the banner once the stream completes
    _moveProgress = MoveProgress.idle();
    notifyListeners();
  }

  ImageProvider thumbnailProviderFor(String assetId) {
    return _mediaAssetRepo.thumbnailProviderFor(assetId);
  }
}
