import 'package:flutter/foundation.dart';
import 'package:mobile_image_search/src/core/platform_image_method_channel.dart';
import 'package:mobile_image_search/src/data/interfaces/media_asset_repository_interface.dart';
import 'package:mobile_image_search/src/data/repositories/image_embedding_repository.dart';
import 'package:mobile_image_search/src/data/repositories/media_asset_repository.dart';
import 'package:mobile_image_search/src/feature/gallery/data/android_album_repo.dart';
import 'package:mobile_image_search/src/feature/gallery/data/android_trash_repo.dart';
import 'package:mobile_image_search/src/feature/gallery/domain/album_form_validator.dart';
import 'package:mobile_image_search/src/data/interfaces/trash_repository_interface.dart';
import 'package:mobile_image_search/src/data/services/indexing_service.dart';
import 'package:mobile_image_search/src/data/services/background_worker_service.dart';
import 'package:mobile_image_search/src/feature/evaluation/data/evaluation_service.dart';
import 'package:mobile_image_search/src/feature/evaluation/presentation/evaluation_viewmodel.dart';
import 'package:mobile_image_search/src/feature/gallery/viewmodels/album_viewmodel.dart';
import 'package:mobile_image_search/src/feature/gallery/viewmodels/gallery_viewmodel.dart';
import 'package:mobile_image_search/src/feature/gallery/viewmodels/selection_viewmodel.dart';
import 'package:mobile_image_search/src/feature/search/domain/query_validator.dart';
import 'package:mobile_image_search/src/shared/domain/interface/album_repository_interface.dart';
import 'package:mobile_image_search/src/feature/gallery/viewmodels/trash_viewmodel.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_repository.dart';
import 'package:mobile_image_search/src/domain/bpe_tokenizer.dart';
import 'package:mobile_image_search/src/feature/search/viewmodels/image_search_viewmodel.dart';
import 'package:mobile_image_search/src/infra/asset_loader.dart';
import 'package:path_provider/path_provider.dart';

class ServiceLocator {
  static final ObjectBoxService objectBoxService = ObjectBoxService.instance;
  static late final ITrashRepository trashRepository;
  static late final IAlbumRepository albumRepository;
  static late final PlatformChannelService platformChannelService;
  static late final IndexingService indexingService;
  static late final BackgroundWorkerService backgroundWorkerService;

  static late final BpeTokenizer bpeTokenizer;
  static late final QueryValidator queryValidator;

  static late final IMediaAssetRepository mediaAssetRepository;
  static late final ImageEmbeddingRepository imageEmbeddingRepository;

  // extracted model/tokenizer file paths (set during init)
  static late final String textEncoderPath;
  static late final String imageEncoderPath;
  static late final String vocabPath;
  static late final String mergesPath;

  // evaluation (developer tool)
  static late final EvaluationService evaluationService;
  static late final EvaluationViewModel evaluationViewModel;

  // viewmodels
  static late final SearchViewModel searchViewModel;
  static late final TrashViewModel trashViewModel;
  static late final GalleryViewModel galleryViewModel;
  static late final AlbumViewModel albumViewModel;
  static late final SelectionViewModel selectionViewModel;

  static Future<void> init() async {
    debugPrint("[ServiceLocator] Initializing...");

    mediaAssetRepository = MediaAssetRepository();

    await objectBoxService.init();

    backgroundWorkerService = BackgroundWorkerService();

    // repositories init
    imageEmbeddingRepository = ImageEmbeddingRepository(
      objectBoxClient: objectBoxService,
      bgWorkerClient: backgroundWorkerService,
    );

    // Trash
    platformChannelService = PlatformChannelService();
    trashRepository = AndroidTrashRepository(
      objectBoxStoreClient: objectBoxService,
      methodChannel: platformChannelService,
    );
    trashViewModel = TrashViewModel(
      trashRepo: trashRepository,
      mediaAssetRepo: mediaAssetRepository,
      imageEmbeddingRepo: imageEmbeddingRepository,
    );
    try {
      await trashViewModel.loadFromDatabase();
    } catch (e) {
      debugPrint("[ServiceLocator] Failed to load trash, continuing: $e");
    }

    // Album
    albumRepository = AndroidAlbumRepository(
      platformChannelClient: platformChannelService,
      objectBoxClient: objectBoxService,
    );
    await albumRepository.syncAlbums();
    // albumViewModel is constructed later, after queryValidator is ready
    // (the album create form validates its description like a search phrase)

    // shared multi-select state (gallery grid + opened albums)
    selectionViewModel = SelectionViewModel();

    // asset extraction - centralized in AssetLoader
    debugPrint('[ServiceLocator] Extracting bundled assets...');
    final assetLoader = AssetLoader();
    await assetLoader.extractAll();
    debugPrint('[ServiceLocator] Assets extracted successfully.');

    textEncoderPath = assetLoader.textEncoderPath;
    imageEncoderPath = assetLoader.imageEncoderPath;
    vocabPath = assetLoader.vocabPath;
    mergesPath = assetLoader.mergesPath;

    await backgroundWorkerService.init(
      textEncoderPath: textEncoderPath,
      imageEncoderPath: imageEncoderPath,
      vocabPath: vocabPath,
      mergesPath: mergesPath,
      storeReference: objectBoxService.store.reference,
    );
    indexingService = IndexingService(
      workerIsolateClient: backgroundWorkerService,
    );
    await indexingService.init();

    // evaluation (developer tool)
    evaluationService = EvaluationService(
      workerService: backgroundWorkerService,
      textEncoderPath: textEncoderPath,
      imageEncoderPath: imageEncoderPath,
      vocabPath: vocabPath,
      mergesPath: mergesPath,
    );
    evaluationViewModel = EvaluationViewModel(service: evaluationService);

    // byte pair encoding tokenizer
    bpeTokenizer = BpeTokenizer();
    await bpeTokenizer.init(
      vocabExtractedPath: assetLoader.vocabPath,
      mergesExtractedPath: assetLoader.mergesPath,
    );
    queryValidator = QueryValidator(bpeTokenizer: bpeTokenizer);

    // album (form validates its description like a search phrase)
    albumViewModel = AlbumViewModel(
      albumRepo: albumRepository,
      mediaAssetRepo: mediaAssetRepository,
      imageEmbeddingRepo: imageEmbeddingRepository,
      trashRepo: trashRepository,
      albumFormValidator: AlbumFormValidator(queryValidator: queryValidator),
    );

    // gallery
    galleryViewModel = GalleryViewModel(mediaAssetRepo: mediaAssetRepository);

    // search ViewModel
    searchViewModel = SearchViewModel(
      imageEmbeddingRepository: imageEmbeddingRepository,
      mediaAssetRepo: mediaAssetRepository,
      queryValidator: queryValidator,
    );

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
