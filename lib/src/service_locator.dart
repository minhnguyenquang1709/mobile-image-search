import 'package:flutter/foundation.dart';
import 'package:mobile_image_search/src/core/platform_image_method_channel.dart';
import 'package:mobile_image_search/src/feature/gallery/application/album_service.dart';
import 'package:mobile_image_search/src/feature/gallery/application/gallery_service.dart';
import 'package:mobile_image_search/src/feature/gallery/application/trash_service.dart';
import 'package:mobile_image_search/src/feature/gallery/data/android_album_repo.dart';
import 'package:mobile_image_search/src/feature/gallery/data/android_gallery_repository.dart';
import 'package:mobile_image_search/src/feature/gallery/data/android_trash_repo.dart';
import 'package:mobile_image_search/src/feature/gallery/data/gallery_data_source.dart';
import 'package:mobile_image_search/src/feature/gallery/domain/trash_repository_interface.dart';
import 'package:mobile_image_search/src/feature/indexing/application/indexing_service.dart';
import 'package:mobile_image_search/src/feature/indexing/data/background_worker_data_source.dart';
import 'package:mobile_image_search/src/shared/domain/interface/gallery_repository_interface.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/trash_view_model.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_repository.dart';
import 'package:path_provider/path_provider.dart';

class ServiceLocator {
  static final ObjectBoxClient objectBoxClient = ObjectBoxClient.instance;
  static late final ITrashRepository trashRepository;
  static late final TrashService trashService;
  static late final IGalleryRepository galleryRepository;
  static late final GalleryService galleryService;
  static late final PlatformChannelClient platformChannelClient;
  static late final AlbumService albumService;
  static late final IndexingService indexingService;

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

    // background indexing
    final backgroundWorkerDataSource = BackgroundWorkerDataSource();
    await backgroundWorkerDataSource.init();
    indexingService = IndexingService(
      workerIsolateClient: backgroundWorkerDataSource,
      galleryRepository: galleryRepository,
      objectBoxClient: objectBoxClient,
    );
    await indexingService.init();

    // debugging
    // path_provider
    debugPrint("[ServiceLocator] ===== Path Provider Directories =====");

    try {
      final tempDir = await getTemporaryDirectory();
      debugPrint(
        "[ServiceLocator] Temporary directory `getTemporaryDirectory()`: ${tempDir.path}",
      );
    } catch (e) {
      debugPrint("[ServiceLocator] Temporary directory error: $e");
    }

    try {
      final appDocsDir = await getApplicationDocumentsDirectory();
      debugPrint(
        "[ServiceLocator] Application documents directory `getApplicationDocumentsDirectory()`: ${appDocsDir.path}",
      );
    } catch (e) {
      debugPrint("[ServiceLocator] Application documents directory error: $e");
    }

    try {
      final appSupportDir = await getApplicationSupportDirectory();
      debugPrint(
        "[ServiceLocator] Application support directory `getApplicationSupportDirectory()`: ${appSupportDir.path}",
      );
    } catch (e) {
      debugPrint("[ServiceLocator] Application support directory error: $e");
    }

    try {
      final appCacheDir = await getApplicationCacheDirectory();
      debugPrint(
        "[ServiceLocator] Application cache directory `getApplicationCacheDirectory()`: ${appCacheDir.path}",
      );
    } catch (e) {
      debugPrint("[ServiceLocator] Application cache directory error: $e");
    }

    try {
      final externalDir = await getExternalStorageDirectory();
      debugPrint(
        "[ServiceLocator] External storage directory `getExternalStorageDirectory()`: ${externalDir?.path ?? 'null'}",
      );
    } catch (e) {
      debugPrint("[ServiceLocator] External storage directory error: $e");
    }

    try {
      final externalCacheDirs = await getExternalCacheDirectories();
      if (externalCacheDirs != null && externalCacheDirs.isNotEmpty) {
        debugPrint(
          "[ServiceLocator] External cache directories `getExternalCacheDirectories()`: ${externalCacheDirs.length} found",
        );
        for (int i = 0; i < externalCacheDirs.length; i++) {
          debugPrint(
            "[ServiceLocator] External cache directory [$i]: ${externalCacheDirs[i].path}",
          );
        }
      } else {
        debugPrint(
          "[ServiceLocator] External cache directories: null or empty",
        );
      }
    } catch (e) {
      debugPrint("[ServiceLocator] External cache directories error: $e");
    }

    try {
      final externalStorageDirs = await getExternalStorageDirectories();
      if (externalStorageDirs != null && externalStorageDirs.isNotEmpty) {
        debugPrint(
          "[ServiceLocator] External storage directories `getExternalStorageDirectories()`: ${externalStorageDirs.length} found",
        );
        for (int i = 0; i < externalStorageDirs.length; i++) {
          debugPrint(
            "[ServiceLocator] External storage directory [$i]: ${externalStorageDirs[i].path}",
          );
        }
      } else {
        debugPrint(
          "[ServiceLocator] External storage directories: null or empty",
        );
      }
    } catch (e) {
      debugPrint("[ServiceLocator] External storage directories error: $e");
    }

    try {
      final downloadsDir = await getDownloadsDirectory();
      debugPrint(
        "[ServiceLocator] Downloads directory `getDownloadsDirectory()`: ${downloadsDir?.path ?? 'null'}",
      );
    } catch (e) {
      debugPrint("[ServiceLocator] Downloads directory error: $e");
    }

    debugPrint("[ServiceLocator] ===== End Path Provider Directories =====");
  }
}
