import 'package:mobile_image_search/src/shared/domain/model/album.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:mobile_image_search/src/shared/domain/model/move_progress.dart';

abstract class IAlbumRepository {
  /// Get the list of albums on the device
  ///
  /// - Android: albums are represented by directories having at least one image or video file in the device storage. The album name is the same as the directory name.
  ///
  /// - iOS: albums are represented by collections in the Photos library. The album name is the same as the collection name.
  Future<List<Album>> getAlbums();

  /// Move [assets] into [album] (copy then delete originals), streaming
  /// [MoveProgress] as it advances. The destination folder is resolved from the
  /// album's existing location so media lands in the same bucket (no duplicate).
  Stream<MoveProgress> moveAssetsToAlbum(Album album, List<MediaAsset> assets);

  /// A new album is created by
  ///
  /// - creating a new album entry in database
  ///
  /// - create a new folder in Android device or a new collection in iOS device (TBD)
  Future<Album> createAlbum(String albumTitle, [String? description]);

  /// Sync albums between app database and platform albums
  Future<void> syncAlbums();

  /// Delete an album given its ID.
  /// Optionally delete media assets in the album as well.
  ///
  /// Album ID is BUCKET_ID in Android and localIdentifier in iOS.
  ///
  /// - Android: delete both the album entry in database and corresponding directory
  ///
  /// - iOS: TBD
  Future<void> deleteAlbum(String albumId, {bool deleteAssets = false});
}
