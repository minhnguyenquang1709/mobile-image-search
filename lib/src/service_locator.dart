import 'package:flutter/foundation.dart';
import 'package:mobile_image_search/src/core/platform_image_method_channel.dart';
import 'package:mobile_image_search/src/feature/gallery/application/album_service.dart';
import 'package:mobile_image_search/src/feature/gallery/application/gallery_service.dart';
import 'package:mobile_image_search/src/feature/gallery/application/trash_service.dart';
import 'package:mobile_image_search/src/feature/gallery/data/album_repo.dart';
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
  static late final PlatformChannelClient platformChannelClient;
  static late final AlbumService albumService;

  static Future<void> init() async {
    debugPrint("[ServiceLocator] Initializing...");
    await objectBoxClient.init();

    // Gallery
    final mediaPlatformChannel = PlatformChannelClient();
    final galleryDataSource = GalleryDataSource(mediaPlatformChannel);
    galleryRepository = AndroidGalleryRepository(galleryDataSource);
    galleryService = GalleryService(galleryRepository);

    // Trash
    platformChannelClient = PlatformChannelClient();
    trashRepository = AndroidTrashRepository(
      objectBoxStoreClient: objectBoxClient,
      methodChannel: platformChannelClient,
    );
    trashService = TrashService(trashRepository);
    await TrashViewModel.instance.loadFromDatabase();

    // Album
    final albumRepo = AndroidAlbumRepository(
      platformChannelClient: platformChannelClient,
      objectBoxClient: objectBoxClient,
    );
    albumService = AlbumService(albumRepo);
    await albumRepo.syncAlbums();
  }
}
