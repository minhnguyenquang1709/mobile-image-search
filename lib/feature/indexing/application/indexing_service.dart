import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/core/config/config.dart';
import 'package:mobile_image_search/core/infra/background_worker_interface.dart';
import 'package:mobile_image_search/core/utils/logger.dart';
import 'package:mobile_image_search/feature/indexing/domain/indexing_model.dart';
import 'package:mobile_image_search/shared/data/data_source/onnx_data_source.dart';
import 'package:mobile_image_search/shared/data/repository/ai_inference_repository.dart';
import 'package:mobile_image_search/shared/data/repository/objectbox_store_repository.dart';
import 'package:mobile_image_search/shared/domain/interface/store_repository_interface.dart';
import 'package:mobile_image_search/shared/domain/media.dart';
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
    final WorkerSetupConfig config = args[0] as WorkerSetupConfig;
    final String? textEncoderExtractedPath = args[1];
    final String? imageEncoderExtractedPath = args[2];
    final String? bpeVocabExtractedPath = args[3];
    final String? bpeMergesExtractedPath = args[4];

    // register isolate to allow using plugins
    BackgroundIsolateBinaryMessenger.ensureInitialized(config.rootIsolateToken);

    // set up communication channel
    final workerReceivePort = ReceivePort();
    config.mainSendPort.send(workerReceivePort.sendPort);

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
            config.mainSendPort.send(
              IndexingResult.failure(message.media, 'Asset not found'),
            );
            return;
          }

          final File? imageFile = await imageAsset.file;
          if (imageFile == null) {
            config.mainSendPort.send(
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
          config.mainSendPort.send(result);
        } catch (e, _) {
          // error throwing
          config.mainSendPort.send(
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

  IndexingService({required IStoreRepository storeRepository})
    : _storeRepository = storeRepository;

  bool _isWorkerReady = false;
  bool _isProcessing = false;

  /// Copy model files from assets to file system to allow worker isolate to read
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
    } catch (e, _) {
      rethrow;
    }
  }

  void enQueue(List<Media> assetIds) {
    taskQueue.addAll(assetIds.map((id) => IndexingTask(media: id)));
    _logger.printLog('Enqueued indexing task for image $assetIds');
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
  final service = IndexingService(storeRepository: storeRepository);
  await service.initialize();
  return service;
});
