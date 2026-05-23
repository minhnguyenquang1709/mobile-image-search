import 'package:flutter/foundation.dart';
import 'package:mobile_image_search/src/core/platform_image_method_channel.dart';
import 'package:mobile_image_search/src/feature/gallery/application/gallery_service.dart';
import 'package:mobile_image_search/src/feature/gallery/application/trash_service.dart';
import 'package:mobile_image_search/src/feature/gallery/data/android_gallery_repository.dart';
import 'package:mobile_image_search/src/feature/gallery/data/android_trash_repo.dart';
import 'package:mobile_image_search/src/feature/gallery/data/gallery_data_source.dart';
import 'package:mobile_image_search/src/feature/gallery/domain/trash_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/interface/gallery_repository_interface.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/trash_view_model.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_repository.dart';

class ServiceLocator {
  static final ObjectBoxClient objectBoxClient = ObjectBoxClient.instance;
  static late final ITrashRepository trashRepository;
  static late final TrashService trashService;
  static late final IGalleryRepository galleryRepository;
  static late final GalleryService galleryService;
  static late final PlatformMethodChannel platformMethodChannel;

  static Future<void> init() async {
    debugPrint("[ServiceLocator] Initializing...");
    await objectBoxClient.init();

    // Gallery
    final mediaPlatformChannel = PlatformMethodChannel();
    final galleryDataSource = GalleryDataSource(mediaPlatformChannel);
    galleryRepository = AndroidGalleryRepository(galleryDataSource);
    galleryService = GalleryService(galleryRepository);

    // Trash
    platformMethodChannel = PlatformMethodChannel();
    trashRepository = AndroidTrashRepository(
      objectBoxStoreClient: objectBoxClient,
      methodChannel: platformMethodChannel,
    );
    trashService = TrashService(trashRepository);
    await TrashViewModel.instance.loadFromDatabase();
  }
}
