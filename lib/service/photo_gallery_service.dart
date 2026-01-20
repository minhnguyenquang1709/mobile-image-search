// ignore_for_file: unnecessary_this

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:mobile_image_search/utils/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoGalleryService {
  static final PhotoGalleryService _instance = PhotoGalleryService._internal();

  bool isGalleryAccessGranted = false;
  bool isGallerySynced = false;

  final _logger = loggers[LoggerName.PhotoGalleryService]!;

  List<AssetEntity> _assets = [];

  List<AssetEntity> get assets => _assets;

  factory PhotoGalleryService() {
    return _instance;
  }

  PhotoGalleryService._internal();

  Future<void> init() async {
    try {
      await requestGalleryAccess();
    } catch (e) {
      _logger.printLog('Error initializing PhotoGalleryService: $e');
      rethrow;
    }
    if (isGalleryAccessGranted) {
      try {
        await syncGallery();
      } catch (e) {
        _logger.printLog('Error syncing gallery: $e');
        rethrow;
      }
    }
  }

  /// read gallery albums and cache them in memory and record the number of image files
  Future<void> syncGallery() async {
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
        return;
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
      this._assets = allAssets;

      _logger.printLog('Found ${assetIds.length} assets (images) in total.');
    } catch (e) {
      _logger.printLog('Error syncing gallery: $e');
      rethrow;
    }
  }

  Future<void> requestGalleryAccess() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final int sdkInt = androidInfo.version.sdkInt;

      if (sdkInt < 33) {
        final storagePermission = await Permission.storage.status;
        if (storagePermission.isGranted) {
          isGalleryAccessGranted = true;
        }
        if (storagePermission.isDenied) {
          final status = await Permission.storage.request();

          isGalleryAccessGranted = status.isGranted;
          _logger.printLog('Gallery access granted: $isGalleryAccessGranted');
        }
        if (storagePermission.isPermanentlyDenied ||
            storagePermission.isRestricted) {
          // Open app settings so the user can grant permission
          await openAppSettings();
        }
      } else {
        // For Android 13 and above, use photos permission
        final photoStorage = await Permission.photos.status;
        if (photoStorage.isGranted) {
          isGalleryAccessGranted = true;
        }
        if (photoStorage.isDenied) {
          final status = await Permission.photos.request();
          isGalleryAccessGranted = status.isGranted;
          _logger.printLog('Gallery access granted: $isGalleryAccessGranted');
        }
        if (photoStorage.isPermanentlyDenied || photoStorage.isRestricted) {
          await openAppSettings();
        }
      }
    } else if (Platform.isIOS) {
      final photoStorage = await Permission.photos.status;
      if (photoStorage.isGranted) {
        isGalleryAccessGranted = true;
      }
      if (photoStorage.isDenied) {
        final status = await Permission.photos.request();
        isGalleryAccessGranted = status.isGranted;
        _logger.printLog('Gallery access granted: $isGalleryAccessGranted');
      }
      if (photoStorage.isPermanentlyDenied || photoStorage.isRestricted) {
        await openAppSettings();
      }
    }
  }
}
