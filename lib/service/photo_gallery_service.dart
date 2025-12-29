import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:mobile_image_search/utils/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoGalleryService {
  static final PhotoGalleryService _instance = PhotoGalleryService._internal();

  bool isGalleryAccessGranted = false;
  bool isGallerySynced = false;

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
      debugLogger.printLog('Error initializing PhotoGalleryService: $e');
      rethrow;
    }
    if (isGalleryAccessGranted) {
      try {
        await syncGallery();
      } catch (e) {
        debugLogger.printLog('Error syncing gallery: $e');
        rethrow;
      }
    }
  }

  /// read gallery albums and cache them in memory
  ///
  /// record the number of image files
  Future<void> syncGallery() async {
    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
        filterOption: FilterOptionGroup(
          orders: [
            const OrderOption(type: OrderOptionType.updateDate, asc: false),
          ],
        ),
      );
      if (albums.isNotEmpty) {
        final recentAlbum = albums.first;

        final int assetCount = await recentAlbum.assetCountAsync;

        this._assets = await recentAlbum.getAssetListRange(
          start: 0,
          end: assetCount,
        );

        debugLogger.printLog('Found $assetCount assets (images) in total.');
      } else {
        this._assets = [];
        debugLogger.printLog('No image found in the gallery.');
      }
      debugLogger.printLog('Gallery synced with ${_assets.length} albums.');
    } catch (e) {
      debugLogger.printLog('Error syncing gallery: $e');
      rethrow;
    }
  }

  Future<void> requestGalleryAccess() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      int sdkInt = androidInfo.version.sdkInt;

      if (sdkInt < 33) {
        final storagePermission = await Permission.storage.status;
        if (storagePermission.isGranted) {
          isGalleryAccessGranted = true;
        }
        if (storagePermission.isDenied) {
          final status = await Permission.storage.request();

          isGalleryAccessGranted = status.isGranted;
          debugLogger.printLog(
            'Gallery access granted: $isGalleryAccessGranted',
          );
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
          debugLogger.printLog(
            'Gallery access granted: $isGalleryAccessGranted',
          );
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
        debugLogger.printLog('Gallery access granted: $isGalleryAccessGranted');
      }
      if (photoStorage.isPermanentlyDenied || photoStorage.isRestricted) {
        await openAppSettings();
      }
    }
  }
}
