import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/core/utils/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

/// Get images from device storage
class GalleryDataSource {
  final _logger = loggers[LoggerName.GalleryDataSource]!;

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
        return await Permission.photos.isGranted;
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
        final photoStorage = await Permission.photos.status;
        if (photoStorage.isGranted) {
          return true;
        }
        if (photoStorage.isDenied) {
          final status = await Permission.photos.request();
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

  Future<List<AssetEntity>> getAllImages() async {
    try {
      final FilterOptionGroup filterOptions = FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.updateDate, asc: false),
        ],
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
      _logger.printLog('Found ${albums.length} albums in the gallery.');

      if (albums.isEmpty) {
        _logger.printLog('No image found in the gallery.');
        return [];
      }

      final Set<String> assetIds = {};
      final List<AssetEntity> allAssets = [];

      for (final album in albums) {
        _logger.printLog("Syncing album: ${album.name}");
        final int assetCount = await album.assetCountAsync;
        if (assetCount > 0) {
          final assets = await album.getAssetListRange(
            start: 0,
            end: assetCount,
          );

          for (final asset in assets) {
            if (!assetIds.contains(asset.id)) {
              assetIds.add(asset.id);
              allAssets.add(asset);
            }
          }
        }
      }

      // Sort by update date (newest first)
      allAssets.sort(
        (a, b) => b.modifiedDateTime.compareTo(a.modifiedDateTime),
      );
      return allAssets;
    } catch (e) {
      _logger.printLog('Error syncing gallery: $e');
      rethrow;
    }
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
}

final galleryDataSourceProvider = Provider((ref) {
  return GalleryDataSource();
});
