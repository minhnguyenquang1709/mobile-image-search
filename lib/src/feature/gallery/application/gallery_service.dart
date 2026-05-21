import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/constants/common_constant.dart';
import 'package:mobile_image_search/src/feature/gallery/data/android_gallery_repository.dart';
import 'package:mobile_image_search/src/shared/domain/interface/gallery_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

const isDebug = kDebugMode || kProfileMode;

/// Method channel for request/response communication with native platform
class AppMethodChannel extends MethodChannel {
  const AppMethodChannel(super.name);

  @override
  Future<T?> invokeMethod<T>(String method, [arguments]) {
    if (isDebug) {
      debugPrint('channel=$name method=$method arguments=$arguments');
    }
    return super.invokeMethod(method, arguments);
  }
}

class AppEventChannel extends EventChannel {
  const AppEventChannel(super.name);

  @override
  Stream receiveBroadcastStream([arguments]) {
    if (isDebug) {
      debugPrint('channel=$name arguments=$arguments');
    }
    return super.receiveBroadcastStream(arguments);
  }
}

/// Event received from native platform about media operation result
class MediaOperationEvent {
  final bool success, skipped;

  // URI is like primary key for media asset on android
  final String uri;

  const MediaOperationEvent({
    required this.success,
    required this.skipped,
    required this.uri,
  });

  factory MediaOperationEvent.fromMap(Map map) {
    final bool skipped = map['skipped'] ?? false;
    return MediaOperationEvent(
      success: (map['success'] ?? false) | skipped,
      skipped: skipped,
      uri: map['uri'],
    );
  }
}

class MediaMoveOperationEvent extends MediaOperationEvent {
  final bool deleted;

  const MediaMoveOperationEvent({
    required super.success,
    required super.skipped,
    required super.uri,
    required this.deleted,
  });

  factory MediaMoveOperationEvent.fromMap(Map map) {
    final bool skipped = map['skipped'] ?? false;
    return MediaMoveOperationEvent(
      success: (map['success'] ?? false) | skipped,
      skipped: skipped,
      uri: map['uri'],
      deleted: map['deleted'] ?? false,
    );
  }
}

class GalleryService {
  GalleryService(this._galleryRepository);

  final IGalleryRepository _galleryRepository;

  static const _platformMethodChannel = AppMethodChannel(
    'com.minh.mobile_image_gallery/media_channel',
  );

  static const _platformEventChannel = AppEventChannel(
    'com.minh.mobile_image_gallery/media_event_channel',
  );

  String get newOperationId => DateTime.now().millisecondsSinceEpoch.toString();

  Future<void> cancelOperation(String operationId) async {}

  IGalleryRepository get repository => _galleryRepository;

  /// Move media to album
  Stream<MediaMoveOperationEvent> moveMediaToAlbum({
    required String opId,
    required List<MediaAsset> mediaAssets,
    required String albumName,
  }) {
    try {
      // serialize
      final mediaList = mediaAssets
          .map(
            (asset) => {
              'assetId': int.tryParse(asset.assetId),
              'mediaType': asset.mediaType == EMediaType.video ? 1 : 0,
            },
          )
          .toList();
      return _platformEventChannel
          .receiveBroadcastStream(<String, Object?>{
            'operation': 'moveMediaToAlbum',
            'id': opId,
            'mediaList': mediaList,
            'albumName': albumName,
          })
          .where((event) => event is Map)
          .map((event) => MediaMoveOperationEvent.fromMap(event as Map));
    } on PlatformException catch (e) {
      debugPrint("Failed to move media to album: ${e.message}");
      return Stream.error(e);
    } catch (e) {
      debugPrint("Failed to move media to album: ${e.toString()}");
      return Stream.error(e);
    }
  }

  Future<List<MediaAsset>> readGallery({
    required int page,
    int limit = 100,
  }) async {
    return await _galleryRepository.readGallery(page: page, limit: limit);
  }

  Future<bool> requestGalleryAccess() async {
    return await _galleryRepository.requestGalleryAccess();
  }

  /// delete image from gallery and remove from vector store
  Future<bool> deleteImage(String imageId) async {
    throw UnimplementedError(
      "GalleryService.deleteImage is not implemented yet",
    );
  }

  Future<List<MediaAsset>> getAllMetadata() async {
    return await _galleryRepository.getAllMetadata();
  }

  Future<void> createAlbum(
    String albumName,
    List<MediaAsset> mediaAssets,
  ) async {
    final bool result = await _galleryRepository.createAlbum(
      albumName,
      mediaAssets,
    );
    print("[GalleryService] createAlbum result: $result");
  }

  Future<void> moveToTrash(List<MediaAsset> mediaAssets) async {
    final bool result = await _galleryRepository.moveMediaToTrash(mediaAssets);
    print("[GalleryService] moveToTrash result: $result");
  }
}

final galleryServiceProvider = Provider((ref) {
  final repository = ref.watch(galleryRepositoryProvider);
  return GalleryService(repository);
});
