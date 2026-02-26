import 'package:mobile_image_search/shared/domain/image.dart';

abstract class IGalleryRepository {
  Future<List<Image>> readGallery();
  Future<bool> requestGalleryAccess();
  Future<bool> deleteImage(String imageId);
}
