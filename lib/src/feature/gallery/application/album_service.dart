import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/feature/gallery/data/album_repo.dart';
import 'package:mobile_image_search/src/shared/domain/interface/album_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/album.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

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
}

final albumServiceProvider = Provider((ref) {
  final albumRepo = ref.watch(androidAlbumRepoProvider);
  return AlbumService(albumRepo);
});
