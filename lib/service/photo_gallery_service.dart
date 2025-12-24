import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:mobile_image_search/utils/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoGalleryService {
  static final PhotoGalleryService _instance = PhotoGalleryService._internal();

  bool isGalleryAccessGranted = false;
  bool isGallerySynced = false;

  factory PhotoGalleryService() {
    return _instance;
  }

  PhotoGalleryService._internal();

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

  void syncGallery() {}
}
