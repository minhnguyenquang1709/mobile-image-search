import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/core/constants/common.constant.dart';
import 'package:mobile_image_search/core/utils/logger.dart';
import 'package:mobile_image_search/service/photo_gallery_service.dart';
import 'package:mobile_image_search/service/provider.dart';
import 'package:mobile_image_search/shared/domain/image.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryRepository implements IGalleryRepository {
  List<AssetEntity> _assets = [];
  get assets => _assets;

  bool _hasPermission = false;
  get hasPermission => _hasPermission;

  EGallerySyncStatus _syncStatus = EGallerySyncStatus.idle;

  final Logger _logger = loggers[LoggerName.GalleryRepository]!;

  bool isGallerySynced = false;

  /// read gallery albums and cache them in memory and record the number of image files
  ///
  /// return domain model
  Future<List<Image>> readGallery() async {
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
        this._assets = [];
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
      return allAssets.map((asset) {
        return Image(id: asset.id, createdAt: asset.modifiedDateTime);
      }).toList();
    } catch (e) {
      _logger.printLog('Error syncing gallery: $e');
      rethrow;
    }
  }

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
}

final galleryRepository = GalleryRepository();

// final galleryRepositoryProvider = Provider((ref) {
//   return GalleryRepository(ref.watch(photoGalleryServiceProvider));
// });
