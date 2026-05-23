import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/constants/common_constant.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

class PlatformMethodChannel {
  static const String _channelName =
      'com.minh.mobile_image_gallery/media_channel';

  // method channel with unique name to avoid conflicts with other plugins
  static const MethodChannel _methodChannel = MethodChannel(_channelName);

  Future<int> getBatteryLevel() async {
    try {
      final int result = await _methodChannel.invokeMethod('getBatteryLevel');
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed to get battery level: ${e.message}");
      return -1;
    }
  }

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

  Future<bool> moveMediaToAlbum(List<MediaAsset> mediaAssets) async {
    try {
      final mediaList = mediaAssets.map((mediaAsset) {
        return {
          'assetId': mediaAsset.assetId,
          'mediaType': mediaAsset.mediaType == EMediaType.video
              ? 'video'
              : 'image',
        };
      }).toList();

      return await _methodChannel.invokeMethod('moveMediaToAlbum', {
        'mediaList': mediaList,
      });
    } catch (e) {
      debugPrint("Failed to move media to album: ${e.toString()}");
      return Future.value(false);
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
  return PlatformMethodChannel();
});
