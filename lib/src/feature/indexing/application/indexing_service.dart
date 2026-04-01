import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/constants/config_constant.dart';
import 'package:mobile_image_search/src/feature/gallery/data/gallery_repository.dart';
import 'package:mobile_image_search/src/feature/gallery/domain/gallery_repository_interface.dart';
import 'package:mobile_image_search/src/feature/indexing/domain/background_worker_interface.dart';
import 'package:mobile_image_search/src/utils/logger.dart';
import 'package:mobile_image_search/src/feature/indexing/domain/indexing_model.dart';
import 'package:mobile_image_search/src/feature/indexing/data/onnx_data_source.dart';
import 'package:mobile_image_search/src/feature/indexing/data/ai_inference_repository.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_repository.dart';
import 'package:mobile_image_search/src/feature/indexing/domain/store_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/media.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

/// Represent a background worker, the class instance itself is on main isolate
///
/// `_initWorker` is executed on worker isolate
class IndexingWorker extends IWorker {
  Completer<void> initCompleter = Completer<void>();

  final StreamController<dynamic> _messageController =
      StreamController.broadcast();

  @override
  Stream get onMessage => _messageController.stream;

  @override
  void dispose() {
    isolate?.kill(priority: Isolate.immediate);
    isolate = null;
    mainReceivePort?.close();
    mainReceivePort = null;
    workerSendPort = null;
  }

  @override
  Future<void> init({
    String? textEncoderExtractedPath,
    String? imageEncoderExtractedPath,
    String? bpeVocabExtractedPath,
    String? bpeMergesExtractedPath,
  }) async {
    mainReceivePort = ReceivePort();

    final RootIsolateToken rootToken = RootIsolateToken.instance!;

    final workerSetupConfig = WorkerSetupConfig(
      mainSendPort: mainReceivePort!.sendPort,
      rootIsolateToken: rootToken,
    );

    final spawnArgs = [
      workerSetupConfig,
      textEncoderExtractedPath,
      imageEncoderExtractedPath,
      bpeVocabExtractedPath,
      bpeMergesExtractedPath,
    ];
    isolate = await Isolate.spawn(_initWorker, spawnArgs);
    mainReceivePort?.listen((dynamic message) {
      if (message is SendPort) {
        // set up communication channel
        workerSendPort = message;
        initCompleter.complete();
      } else {
        // send message to service

        // TODO: remove debug print
        // print('[IndexingWorker] Received message from worker: $message');
        _messageController.add(message);
      }
    });

    // finish initialization
    await initCompleter.future;
  }

  static Future<void> _initWorker(List<dynamic> args) async {
    final WorkerSetupConfig workerConfig = args[0] as WorkerSetupConfig;
    final String? textEncoderExtractedPath = args[1];
    final String? imageEncoderExtractedPath = args[2];
    final String? bpeVocabExtractedPath = args[3];
    final String? bpeMergesExtractedPath = args[4];

    // register isolate to allow using plugins
    BackgroundIsolateBinaryMessenger.ensureInitialized(
      workerConfig.rootIsolateToken,
    );

    // set up communication channel
    final workerReceivePort = ReceivePort();
    workerConfig.mainSendPort.send(workerReceivePort.sendPort);

    // set up model inference service, load model
    OnnxDataSource onnxDataSource = OnnxDataSource();
    await onnxDataSource.init(
      textEncoderExtractedPath: textEncoderExtractedPath,
      imageEncoderExtractedPath: imageEncoderExtractedPath,
      bpeVocabExtractedPath: bpeVocabExtractedPath,
      bpeMergesExtractedPath: bpeMergesExtractedPath,
    );
    OnnxInferenceRepository onnxInferenceRepository = OnnxInferenceRepository(
      onnxDataSource,
    );

    // message handler
    workerReceivePort.listen((dynamic message) async {
      if (message is IndexingTask) {
        // perform indexing task
        try {
          final AssetEntity? imageAsset = await AssetEntity.fromId(
            message.media.assetId,
          );

          if (imageAsset == null) {
            workerConfig.mainSendPort.send(
              IndexingResult.failure(message.media, 'Asset not found'),
            );
            return;
          }

          final File? imageFile = await imageAsset.file;
          if (imageFile == null) {
            workerConfig.mainSendPort.send(
              IndexingResult.failure(message.media, 'File not found'),
            );
            return;
          }
          final Float32List embedding = await onnxInferenceRepository
              .encodeImage(imageFile);

          final IndexingResult result = IndexingResult.success(
            message.media,
            embedding,
          );
          workerConfig.mainSendPort.send(result);
        } catch (e, _) {
          // error throwing
          workerConfig.mainSendPort.send(
            IndexingResult.failure(message.media, 'Error: $e'),
          );
        }
      }
    });
  }
}

class IndexingService {
  final Queue<IndexingTask> taskQueue = Queue<IndexingTask>();

  final IndexingWorker _worker = IndexingWorker();

  final Logger _logger = loggers[LoggerName.indexingService]!;

  final IStoreRepository _storeRepository;
  final IGalleryRepository _galleryRepository;

  IndexingService({
    required IStoreRepository storeRepository,
    required IGalleryRepository galleryRepository,
  }) : _galleryRepository = galleryRepository,
       _storeRepository = storeRepository;

  bool _isWorkerReady = false;
  bool _isProcessing = false;

  /// Copy model files from assets to file system to allow worker isolate to read
  ///
  /// Check for necessary gallery change and update indexing on app startup
  Future<void> initialize() async {
    try {
      // extract model to file system for worker to load
      final directory = await getApplicationSupportDirectory();
      final textEncoderFilePath =
          '${directory.path}${Platform.pathSeparator}${Model.textEncoderAssetPath}';
      final imageEncoderFilePath =
          '${directory.path}${Platform.pathSeparator}${Model.imageEncoderAssetPath}';
      final bpeVocabFilePath =
          '${directory.path}${Platform.pathSeparator}${Model.tokenizerDir}${Platform.pathSeparator}vocab.json';
      final bpeMergesFilePath =
          '${directory.path}${Platform.pathSeparator}${Model.tokenizerDir}${Platform.pathSeparator}merges.txt';

      // chgeck if files exist
      final textEncoderFile = File(textEncoderFilePath);
      final imageEncoderFile = File(imageEncoderFilePath);
      final bpeVocabFile = File(bpeVocabFilePath);
      final bpeMergesFile = File(bpeMergesFilePath);
      if (!await textEncoderFile.exists()) {
        _logger.printLog(
          'Extracting text encoder model to $textEncoderFilePath',
        );
        final textEncoderFileData = await rootBundle.load(
          Model.textEncoderAssetPath,
        );
        _logger.printLog("Loaded text encoder model data, writing to file...");

        // create parent directories
        await textEncoderFile.parent.create(recursive: true);

        await textEncoderFile.writeAsBytes(
          textEncoderFileData.buffer.asUint8List(),
          flush: true,
        );
        _logger.printLog("Text encoder model extracted successfully!");
        _logger.printLog(
          "Text encoder file exists: ${await textEncoderFile.exists()}",
        );
      }

      if (!await imageEncoderFile.exists()) {
        final imageEncoderFileData = await rootBundle.load(
          Model.imageEncoderAssetPath,
        );

        // create parent directories
        await imageEncoderFile.parent.create(recursive: true);

        await imageEncoderFile.writeAsBytes(
          imageEncoderFileData.buffer.asUint8List(),
          flush: true,
        );
      }

      if (!await bpeVocabFile.exists()) {
        final bpeVocabFileData = await rootBundle.load(
          '${Model.tokenizerDir}/vocab.json',
        );

        // create parent directories
        await bpeVocabFile.parent.create(recursive: true);

        await bpeVocabFile.writeAsBytes(
          bpeVocabFileData.buffer.asUint8List(),
          flush: true,
        );
      }

      if (!await bpeMergesFile.exists()) {
        final bpeMergesFileData = await rootBundle.load(
          '${Model.tokenizerDir}/merges.txt',
        );

        // create parent directories
        await bpeMergesFile.parent.create(recursive: true);

        await bpeMergesFile.writeAsBytes(
          bpeMergesFileData.buffer.asUint8List(),
          flush: true,
        );
        _logger.printLog(
          "Tokenizer vocab file exists: ${await bpeVocabFile.exists()}",
        );
      }

      // init background isolate
      await _worker.init(
        textEncoderExtractedPath: textEncoderFilePath,
        imageEncoderExtractedPath: imageEncoderFilePath,
        bpeMergesExtractedPath: bpeMergesFilePath,
        bpeVocabExtractedPath: bpeVocabFilePath,
      );
      _isWorkerReady = true;
      _worker.onMessage.listen((message) {
        handleWorkerResult(message);
      });

      // check for necessary gallery change and update indexing on app startup
      // final List<Media> pendingAssets = [];
      // final List<String> deletePendingAssetIds = [];

      // _logger.printLog('Checking for gallery changes on startup...');
      // final allGalleryMedia = await _galleryRepository.getAllMetadata();
      // final allIndexedMedia = await _storeRepository
      //     .getAllIndexedMediaMetadata();

      // for (final media in allGalleryMedia) {
      //   final indexedMedia = allIndexedMedia[media.assetId];
      //   if (indexedMedia == null) {
      //     // new asset, need indexing
      //     pendingAssets.add(media);
      //   } else {
      //     // existing asset, check for modification
      //     if (media.modifiedDateTime.isAfter(indexedMedia.modifiedDateTime)) {
      //       // asset modified, need re-indexing
      //       pendingAssets.add(media);
      //     }
      //   }
      //   allIndexedMedia.remove(media.assetId);
      // }

      // // remaining items in allIndexedMedia are deleted from gallery, need to remove from index
      // deletePendingAssetIds.addAll(allIndexedMedia.keys);

      // enQueue(pendingAssets);
      // processNextTask();
      // _storeRepository.deleteImageEmbeddings(deletePendingAssetIds);

      // _logger.printLog(
      //   'Gallery change check completed. ${pendingAssets.length} assets pending indexing, ${deletePendingAssetIds.length} assets pending deletion from index.',
      // );
    } catch (e, _) {
      rethrow;
    }
  }

  void enQueue(List<Media> media) {
    taskQueue.addAll(media.map((item) => IndexingTask(media: item)));
    _logger.printLog('Enqueued indexing task for image $media');
  }

  void processNextTask() {
    if (!_isWorkerReady || taskQueue.isEmpty || _isProcessing) {
      return;
    }

    _isProcessing = true;
    final task = taskQueue.removeFirst();

    // send task to worker
    _logger.printLog('Start processing indexing task for image ${task.media}');
    _worker.workerSendPort?.send(task);
  }

  void handleWorkerResult(dynamic message) {
    if (message is IndexingResult) {
      if (message.embedding != null) {
        // save to db
        _storeRepository.saveImageEmbedding(message.media, message.embedding!);
        _logger.printLog(
          'Indexed asset ${message.media.assetId} successfully!',
        );
      } else {
        // error handling
        _logger.printLog(
          "Error indexing asset ${message.media.assetId}: ${message.errorMessage}",
        );
      }

      _isProcessing = false;
      processNextTask();
    }
  }
}

final indexingServiceProvider = FutureProvider((ref) async {
  final storeRepository = await ref.watch(objectBoxStoreRepoProvider.future);
  final galleryRepository = ref.watch(galleryRepositoryProvider);
  final service = IndexingService(
    storeRepository: storeRepository,
    galleryRepository: galleryRepository,
  );
  await service.initialize();
  return service;
});
