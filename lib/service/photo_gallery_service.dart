import 'package:mobile_image_search/feature/gallery/data/gallery_repository.dart';
import 'package:mobile_image_search/shared/domain/image.dart';
import 'package:photo_manager/photo_manager.dart';

abstract class IGalleryRepository {
  Future<List<Image>> readGallery();
  Future<bool> requestGalleryAccess();
}

class PhotoGalleryService {
  final IGalleryRepository _galleryRepository;
  PhotoGalleryService(this._galleryRepository);
}

final photoGalleryService = PhotoGalleryService(galleryRepository);
