import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/core/platform_image_method_channel.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:mobile_image_search/src/utils/media_processing.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

/// Get images from device storage
class GalleryDataSource {
  final MediaPlatformChannel _mediaPlatformChannel;
  AssetPathEntity? _rootAlbum;

  GalleryDataSource(MediaPlatformChannel mediaPlatformChannel)
    : _mediaPlatformChannel = mediaPlatformChannel;

  /// Call photo_manager to check permission
  Future<bool> checkGalleryPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final int sdkInt = androidInfo.version.sdkInt;

      if (sdkInt < 33) {
        // for Android 12 and below
        return await Permission.storage.isGranted;
      } else {
        // for Android 13 and above, use photos permission
        return await Permission.photos.isGranted &&
            await Permission.videos.isGranted;
      }
    } else if (Platform.isIOS) {
      return await Permission.photos.isGranted;
    } else {
      throw UnsupportedError(
        'Unsupported platform. The supported platforms are Android and iOS.',
      );
    }
  }

  /// Request gallery access
  Future<bool> requestGalleryAccess() async {
    bool result = false;

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final int sdkInt = androidInfo.version.sdkInt;

      if (sdkInt < 33) {
        // for Android 12 and below
        final storagePermission = await Permission.storage.status;
        if (storagePermission.isGranted) {
          return true;
        }
        if (storagePermission.isDenied) {
          final PermissionStatus status = await Permission.storage.request();

          return status.isGranted;
        }
        if (storagePermission.isPermanentlyDenied ||
            storagePermission.isRestricted) {
          // open app settings so the user can grant permission
          await openAppSettings();

          // recheck
          final PermissionStatus newStatus = await Permission.storage.status;

          return newStatus.isGranted;
        }
      } else {
        // for Android 13 and above, use photos permission
        // photo and video access are separated
        // final photoStorage = await Permission.photos.status;
        // if (photoStorage.isGranted) {
        //   return true;
        // }
        // if (photoStorage.isDenied) {
        //   final status = await Permission.photos.request();
        //   appLogger.i('Gallery access granted: ${status.isGranted}');
        //   return status.isGranted;
        // }
        // if (photoStorage.isPermanentlyDenied || photoStorage.isRestricted) {
        //   await openAppSettings();

        //   // recheck
        //   final PermissionStatus newStatus = await Permission.photos.status;
        //   appLogger.i(
        //     'Gallery access granted after opening settings: ${newStatus.isGranted}',
        //   );
        //   return newStatus.isGranted;
        // }

        Map<Permission, PermissionStatus> statuses = await [
          Permission.photos,
          Permission.videos,
        ].request();

        final photosGranted = statuses[Permission.photos]?.isGranted ?? false;
        final videosGranted = statuses[Permission.videos]?.isGranted ?? false;

        if (photosGranted && videosGranted) {
          return true;
        }

        if (statuses[Permission.photos]!.isPermanentlyDenied ||
            statuses[Permission.videos]!.isPermanentlyDenied) {
          await openAppSettings();
          // recheck after returning from settings
          return await checkGalleryPermission();
        }
        return false;
      }
    } else if (Platform.isIOS) {
      final photoStorage = await Permission.photos.status;
      if (photoStorage.isGranted) {
        return true;
      }
      if (photoStorage.isDenied) {
        final PermissionStatus status = await Permission.photos.request();
        return status.isGranted;
      }
      if (photoStorage.isPermanentlyDenied || photoStorage.isRestricted) {
        await openAppSettings();

        // recheck
        final PermissionStatus newStatus = await Permission.photos.status;

        return newStatus.isGranted;
      }
    }

    return result;
  }

  /// read all images no matter the album
  Future<List<AssetEntity>> getAllImages() async {
    // filter options
    final FilterOptionGroup filterOptions = FilterOptionGroup(
      orders: [const OrderOption(type: OrderOptionType.updateDate, asc: false)],
    );
    filterOptions.setOption(
      AssetType.image,
      const FilterOption(needTitle: true),
    );
    filterOptions.setOption(
      AssetType.video,
      const FilterOption(needTitle: true),
    );
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
      filterOption: filterOptions,
    );
    // appLogger.i('Found ${albums.length} albums in the gallery.');

    if (albums.isEmpty) {}

    final Set<String> assetIds = {};
    final List<AssetEntity> allAssets = [];

    for (final album in albums) {
      final int assetCount = await album.assetCountAsync;
      if (assetCount > 0) {
        final assets = await album.getAssetListRange(start: 0, end: assetCount);

        for (final asset in assets) {
          if (!assetIds.contains(asset.id)) {
            assetIds.add(asset.id);
            allAssets.add(asset);
          }
        }
      }
    }

    // Sort by update date (newest first)
    // allAssets.sort((a, b) => b.modifiedDateTime.compareTo(a.modifiedDateTime));
    return allAssets;
  }

  Future<List<AssetEntity>> getImagesPaginationSupport({
    int page = 0,
    int limit = 50,
  }) async {
    if (_rootAlbum == null) {
      // filter options
      final FilterOptionGroup filterOptions = FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      );
      filterOptions.setOption(
        AssetType.image,
        const FilterOption(needTitle: true),
      );
      filterOptions.setOption(
        AssetType.video,
        const FilterOption(needTitle: true),
      );

      // get albums
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        onlyAll: true, // only get the root album
        filterOption: filterOptions,
      );

      // get root album (contains all images, sorted by date desc)
      if (albums.isEmpty) {
        return [];
      }

      final AssetPathEntity rootAlbum = albums.first;
      _rootAlbum = rootAlbum;
    }

    final List<AssetEntity> assetPage = await _rootAlbum!.getAssetListPaged(
      page: page,
      size: limit,
    );

    return assetPage;
  }

  Future<bool> deleteImages(List<String> imageIds) async {
    try {
      await PhotoManager.editor.deleteWithIds(imageIds);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<File?> getImageFile(String assetId) async {
    final assetEntity = await AssetEntity.fromId(assetId);

    if (assetEntity == null) {
      return null;
    }

    return await assetEntity.file;
  }

  Future<MediaAsset> getImageMetadata(String assetId) async {
    final assetEntity = await AssetEntity.fromId(assetId);
    try {
      return toMediaAsset(assetEntity!);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<AssetPathEntity>> getAllAlbums() async {
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: false, // get all albums
      hasAll: true, // include "All Photos"/"Recent" album
    );
    // appLogger.i('Found ${albums.length} albums in the gallery.');

    if (albums.isEmpty) {}

    return albums;
  }

  Future<List<AssetEntity>> getImagesFromAlbum({
    required String albumId,
    required int page,
    int limit = 50,
  }) async {
    final List<AssetPathEntity> albumList = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: false,
      hasAll: true,
    );
    final album = albumList.firstWhere((album) => album.id == albumId);

    final List<AssetEntity> assetPage = await album.getAssetListPaged(
      page: page,
      size: limit,
    );

    return assetPage;
  }

  /// Invoke native API via platform channel to create album
  ///
  /// At least one image or video is required to create album
  Future<bool> createAlbum(
    String albumName,
    List<MediaAsset> mediaAssets,
  ) async {
    try {
      print("[GalleryDataSource] invoke native API");
      final bool result = await _mediaPlatformChannel.createAlbum(
        albumName,
        mediaAssets,
      );
      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Invoke native API to move media to album via method channel
  ///
  /// Only support Android for now
  Future<bool> moveMediaToAlbum({
    required List<MediaAsset> mediaAssets,
    required String targetAlbumId,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        "Moving media to album is only supported on Android for now.",
      );
    }

    try {
      final bool result = await _mediaPlatformChannel.moveMediaToAlbum(
        mediaAssets,
      );
      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> moveMediaToTrash(List<MediaAsset> mediaAssets) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        "Moving media to trash is only supported on Android for now.",
      );
    }

    try {
      final bool result = await _mediaPlatformChannel.moveMediaToTrash(
        mediaAssets,
      );
      return result;
    } catch (e) {
      rethrow;
    }
  }
}

final galleryDataSourceProvider = Provider((ref) {
  final MediaPlatformChannel mediaPlatformChannel = ref.watch(
    mediaPlatformChannelProvider,
  );
  return GalleryDataSource(mediaPlatformChannel);
});
