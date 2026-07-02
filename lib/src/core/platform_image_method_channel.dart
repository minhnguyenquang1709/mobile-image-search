import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/core/constants/common_constant.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

/// A service that abstracts the communication with native platform (Android/iOS).
class PlatformChannelService {
  static const String _channelName =
      'com.minh.mobile_image_gallery/media_channel';

  static const String _eventChannelName =
      'com.minh.mobile_image_gallery/media_event_channel';

  // method channel with unique name to avoid conflicts with other plugins
  static const MethodChannel _methodChannel = MethodChannel(_channelName);

  // event channel for streamed operations (e.g. per-file move progress)
  static const EventChannel _eventChannel = EventChannel(_eventChannelName);

  Future<int> getBatteryLevel() async {
    try {
      final int result = await _methodChannel.invokeMethod('getBatteryLevel');
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed to get battery level: ${e.message}");
      return -1;
    }
  }

  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) =>
      _methodChannel.invokeMethod<T>(method, arguments);

  Future<bool> deleteImages(List<String> assetIds) async {
    try {
      return await _methodChannel.invokeMethod('deleteImages', {
        'ids': assetIds,
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to delete images: ${e.message}");
      return Future.value(false);
    }
  }

  Future<bool> createAlbum(
    String albumName,
    List<MediaAsset> mediaAssets,
  ) async {
    try {
      final mediaList = mediaAssets.map((mediaAsset) {
        return {
          'assetId': mediaAsset.assetId,
          'mediaType': mediaAsset.mediaType == EMediaType.video
              ? 'video'
              : 'image',
        };
      }).toList();
      return await _methodChannel.invokeMethod('createAlbum', {
        'albumName': albumName,
        'mediaList': mediaList,
      });
    } on PlatformException catch (e) {
      rethrow;
    }
  }

  /// Start copying [assets] into the album folder at MediaStore [relativePath]
  /// and stream per-file progress events from
  /// native (see MediaEditStreamHandler).
  ///
  /// Each event is a Map with a "state" key: "copying" | "copied" | "error".
  Stream<dynamic> moveMediaToAlbumStream({
    required String relativePath,
    required List<MediaAsset> assets,
  }) {
    final mediaList = assets.map((mediaAsset) {
      return {
        'assetId': int.parse(mediaAsset.assetId),
        'mediaType': mediaAsset.mediaType == EMediaType.video ? 1 : 0,
      };
    }).toList();

    return _eventChannel.receiveBroadcastStream({
      'operation': 'moveMediaToAlbum',
      'relativePath': relativePath,
      'mediaList': mediaList,
    });
  }

  /// Ensure the app has a persisted SAF write grant for the folder at
  /// [relativePath] (used to move into non-standard folders not allowed by
  /// MediaStore). Returns the granted tree Uri string, or null if the user
  /// cancelled or picked a different folder.
  Future<String?> ensureFolderAccess(String relativePath) async {
    try {
      return await _methodChannel.invokeMethod<String>('ensureFolderAccess', {
        'relativePath': relativePath,
      });
    } on PlatformException catch (e) {
      debugPrint("ensureFolderAccess failed: ${e.message}");
      return null;
    }
  }

  /// Same event contract as [moveMediaToAlbumStream] but writes via SAF into the
  /// granted [treeUri] instead of MediaStore. Each "copying" event also carries a
  /// "docUri" (the SAF document) so the originals-delete rollback can undo it.
  Stream<dynamic> moveMediaToAlbumSafStream({
    required String treeUri,
    required List<MediaAsset> assets,
  }) {
    final mediaList = assets.map((mediaAsset) {
      return {
        'assetId': int.parse(mediaAsset.assetId),
        'mediaType': mediaAsset.mediaType == EMediaType.video ? 1 : 0,
      };
    }).toList();

    return _eventChannel.receiveBroadcastStream({
      'operation': 'moveMediaToAlbumSaf',
      'treeUri': treeUri,
      'mediaList': mediaList,
    });
  }

  /// Ask the user to confirm deleting the original [assets] after their copies
  /// were created. [newAssetIds] are the created copies (same order as [assets]),
  /// passed so native can roll them back if the user denies. [docUris] holds the
  /// SAF document Uri per copy (null for MediaStore copies) so SAF copies are
  /// rolled back through SAF.
  ///
  /// Returns true if the originals were deleted, throws PERMISSION_DENIED if not.
  Future<bool> confirmDeleteOriginals(
    List<MediaAsset> assets,
    List<int> newAssetIds, [
    List<String?>? docUris,
  ]) async {
    final assetIds = assets.map((a) => a.assetId).toList();
    final newMediaList = <Map<String, dynamic>>[];
    for (int i = 0; i < newAssetIds.length; i++) {
      newMediaList.add({
        'assetId': newAssetIds[i],
        'mediaType': assets[i].mediaType == EMediaType.video ? 1 : 0,
        'docUri': docUris != null && i < docUris.length ? docUris[i] : null,
      });
    }

    final bool result = await _methodChannel.invokeMethod(
      'confirmDeleteOriginals',
      {'assetIds': assetIds, 'newMediaList': newMediaList},
    );
    return result;
  }

  /// Permanently delete the album's [assets] via MediaStore (shows the system
  /// delete-consent dialog). Sends media types so video Uris are built correctly.
  /// Returns true if the user confirmed, false/throws otherwise.
  Future<bool> permanentlyDeleteAlbumMedia(List<MediaAsset> assets) async {
    final assetIds = assets.map((a) => a.assetId).toList();
    final mediaList = assets.map((a) {
      return {
        'assetId': int.parse(a.assetId),
        'mediaType': a.mediaType == EMediaType.video ? 1 : 0,
      };
    }).toList();

    final bool result = await _methodChannel.invokeMethod('permanentlyDelete', {
      'assetIds': assetIds,
      'mediaList': mediaList,
    });
    return result;
  }

  /// Try to delete the album directory granted as [treeUri] (SAF). Returns true
  /// if it was deleted, false if it was left in place (non-media files remain).
  Future<bool> deleteAlbumDirectory(String treeUri) async {
    try {
      final bool result = await _methodChannel.invokeMethod(
        'deleteAlbumDirectory',
        {'treeUri': treeUri},
      );
      return result;
    } on PlatformException catch (e) {
      debugPrint("deleteAlbumDirectory failed: ${e.message}");
      return false;
    }
  }

  Future<bool> moveMediaToTrash(List<MediaAsset> mediaAssets) async {
    try {
      final mediaList = mediaAssets.map((mediaAsset) {
        return {
          'assetId': mediaAsset.assetId,
          'mediaType': mediaAsset.mediaType == EMediaType.video
              ? 'video'
              : 'image',
        };
      }).toList();

      return await _methodChannel.invokeMethod('moveMediaToTrash', {
        'mediaList': mediaList,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> callNativeMethod(
    String methodName,
    Map<String, dynamic> params,
  ) async {
    try {
      await _methodChannel.invokeMethod(methodName, params);
    } on PlatformException catch (e) {
      debugPrint("Failed to call native method: ${e.message}");
    }
  }
}

final platformMethodChannelProvider = Provider((ref) {
  return PlatformChannelService();
});
