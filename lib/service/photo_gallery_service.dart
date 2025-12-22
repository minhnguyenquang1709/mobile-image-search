import 'package:photo_manager/photo_manager.dart';

class Photogalleryservice {
  static final Photogalleryservice _instance = Photogalleryservice._internal();

  bool isGalleryAccessGranted = false;
  bool isGallerySynced = false;

  factory Photogalleryservice() {
    return _instance;
  }

  Photogalleryservice._internal();

  void requestGalleryAccess() {}

  void syncGallery() {}
}
