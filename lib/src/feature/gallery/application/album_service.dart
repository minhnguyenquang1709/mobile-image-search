import 'package:mobile_image_search/src/shared/domain/interface/album_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/album.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

/// Contains business rules related to Albums.
class AlbumService {
  final IAlbumRepository _albumRepository;

  AlbumService(this._albumRepository);

  Future<List<Album>> getAlbums() async {
    return await _albumRepository.getAlbums();
  }

  Future<List<MediaAsset>> getMediaAssetsInAlbum({
    required String albumId,
    required int page,
    required int limit,
  }) async {
    return await _albumRepository.getMediaAssetsInAlbum(
      albumId: albumId,
      page: page,
      limit: limit,
    );
  }

  Future<Album> createAlbum(String title, [String? description]) async {
    try {
      // business rules
      if (title.trim().isEmpty) throw Exception("Album title cannot be empty");

      return await _albumRepository.createAlbum(title, description);
    } catch (e) {
      throw Exception("Failed to create album: $e");
    }
  }

  Future<void> deleteAlbum(String albumId, {bool deleteAssets = false}) async {
    try {
      await _albumRepository.deleteAlbum(albumId, deleteAssets: deleteAssets);
    } catch (e) {
      throw Exception("Failed to delete album: $e");
    }
  }
}
