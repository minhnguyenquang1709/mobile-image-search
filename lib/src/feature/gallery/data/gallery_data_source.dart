import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/shared/domain/model/media.dart';
import 'package:mobile_image_search/src/utils/logger.dart';
import 'package:mobile_image_search/src/utils/media_processing.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_metadata.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

/// Get images from device storage
class GalleryDataSource {
  final _logger = loggers[LoggerName.galleryDataSource]!;

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
    _logger.printLog('Requesting gallery access permission');
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
          _logger.printLog('Gallery access granted: ${status.isGranted}');

          return status.isGranted;
        }
        if (storagePermission.isPermanentlyDenied ||
            storagePermission.isRestricted) {
          // open app settings so the user can grant permission
          await openAppSettings();

          // recheck
          final PermissionStatus newStatus = await Permission.storage.status;
          _logger.printLog(
            'Gallery access granted after opening settings: ${newStatus.isGranted}',
          );
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
        //   _logger.printLog('Gallery access granted: ${status.isGranted}');
        //   return status.isGranted;
        // }
        // if (photoStorage.isPermanentlyDenied || photoStorage.isRestricted) {
        //   await openAppSettings();

        //   // recheck
        //   final PermissionStatus newStatus = await Permission.photos.status;
        //   _logger.printLog(
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
        _logger.printLog('Gallery access granted: ${photoStorage.isGranted}');
        return true;
      }
      if (photoStorage.isDenied) {
        final PermissionStatus status = await Permission.photos.request();
        _logger.printLog('Gallery access granted: ${status.isGranted}');
        return status.isGranted;
      }
      if (photoStorage.isPermanentlyDenied || photoStorage.isRestricted) {
        await openAppSettings();

        // recheck
        final PermissionStatus newStatus = await Permission.photos.status;
        _logger.printLog(
          'Gallery access granted after opening settings: ${newStatus.isGranted}',
        );
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
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
      filterOption: filterOptions,
    );
    // _logger.printLog('Found ${albums.length} albums in the gallery.');

    if (albums.isEmpty) {
      _logger.printLog('No image found in the gallery.');
    }

    final Set<String> assetIds = {};
    final List<AssetEntity> allAssets = [];

    for (final album in albums) {
      _logger.printLog("Syncing album: ${album.name}");
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

  Future<List<AssetEntity>> getImages({int page = 0, int limit = 50}) async {
    // filter options
    final FilterOptionGroup filterOptions = FilterOptionGroup(
      orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
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

    // TODO: remove debug print
    // _logger.printLog('Found ${albums.length} albums in the gallery.');
    // final List<AssetPathEntity> allAlbums = await PhotoManager.getAssetPathList(
    //   type: RequestType.common,
    //   onlyAll: false, // get all albums
    //   filterOption: filterOptions,
    // );
    // _logger.printLog(
    //   "Found ${allAlbums.length} albums in the gallery (including non-root albums).",
    // );
    // for (int i = 0; i < allAlbums.length; i++) {
    //   final album = allAlbums[i];
    //   final assetCount = await album.assetCountAsync;
    //   _logger.printLog(
    //     "Album ${i + 1}: ${album.name}, asset count: $assetCount",
    //   );
    // }

    if (albums.isEmpty) {
      _logger.printLog('No image found in the gallery.');
    }

    // final Set<String> assetIds = {};
    // final List<AssetEntity> allAssets = [];

    // for (final album in albums) {
    //   _logger.printLog("Syncing album: ${album.name}");
    //   final int assetCount = await album.assetCountAsync;
    //   if (assetCount > 0) {
    //     final start = page * limit;
    //     final assets = await album.getAssetListRange(
    //       start: start,
    //       end: start + limit,
    //     );

    //     for (final asset in assets) {
    //       if (!assetIds.contains(asset.id)) {
    //         assetIds.add(asset.id);
    //         allAssets.add(asset);
    //       }
    //     }
    //   }
    // }

    // Sort by update date (newest first)
    // allAssets.sort((a, b) => b.modifiedDateTime.compareTo(a.modifiedDateTime));
    // return allAssets;

    // get root album (contains all images, sorted by date desc)
    final AssetPathEntity rootAlbum = albums.first;
    final List<AssetEntity> assetPage = await rootAlbum.getAssetListPaged(
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
      _logger.printLog('Error deleting image with id $imageIds: $e');
      return false;
    }
  }

  Future<File?> getImageFile(String assetId) async {
    final assetEntity = await AssetEntity.fromId(assetId);

    if (assetEntity == null) {
      _logger.printLog('AssetEntity not found for assetId $assetId');
      return null;
    }

    return await assetEntity.file;
  }

  Future<Media> getImageMetadata(String assetId) async {
    final assetEntity = await AssetEntity.fromId(assetId);
    try {
      return fillMetadataFromAsset(assetEntity!);
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
    // _logger.printLog('Found ${albums.length} albums in the gallery.');

    if (albums.isEmpty) {
      _logger.printLog('No album found in the gallery.');
    }

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

  Future<void> createAlbum(String albumName) async {}
}

final galleryDataSourceProvider = Provider((ref) {
  return GalleryDataSource();
});
