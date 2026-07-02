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

  static const MethodChannel _methodChannel = MethodChannel(_channelName);

  // event channel for streamed operations
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
