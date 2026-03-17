import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/core/infra/background_worker_interface.dart';
import 'package:mobile_image_search/core/utils/logger.dart';
import 'package:mobile_image_search/feature/indexing/domain/indexing_model.dart';
import 'package:mobile_image_search/shared/data/data_source/onnx_data_source.dart';
import 'package:mobile_image_search/shared/data/repository/ai_inference_repository.dart';
import 'package:mobile_image_search/shared/data/repository/objectbox_store_repository.dart';
import 'package:mobile_image_search/shared/domain/interface/store_repository_interface.dart';
import 'package:photo_manager/photo_manager.dart';

class IndexingWorker extends IWorker {
  Completer<void> initCompleter = Completer<void>();

  final StreamController<dynamic> _messageController =
      StreamController.broadcast();

  @override
  Stream get onMessage => _messageController.stream;

  IndexingWorker() {}

  @override
  void dispose() {
    isolate?.kill(priority: Isolate.immediate);
    isolate = null;
    mainReceivePort?.close();
    mainReceivePort = null;
    workerSendPort = null;
  }

  @override
  Future<void> init() async {
    mainReceivePort = ReceivePort();

    final RootIsolateToken rootToken = RootIsolateToken.instance!;

    final workerSetupConfig = WorkerSetupConfig(
      mainSendPort: mainReceivePort!.sendPort,
      rootIsolateToken: rootToken,
    );

    isolate = await Isolate.spawn(_initWorker, workerSetupConfig);
    mainReceivePort?.listen((dynamic message) {
      // set up communication channel
      if (message is SendPort) {
        workerSendPort = message;
        initCompleter.complete();
      } else {
        print('[IndexingWorker] Received message from worker: $message');
        _messageController.add(message);
      }
    });

    // finish initialization
    await initCompleter.future;
  }

  static Future<void> _initWorker(WorkerSetupConfig config) async {
    // register isolate to allow using plugins
    BackgroundIsolateBinaryMessenger.ensureInitialized(config.rootIsolateToken);

    // set up communication channel
    final workerReceivePort = ReceivePort();
    config.mainSendPort.send(workerReceivePort.sendPort);

    // set up model inference service, load model
    OnnxDataSource onnxDataSource = OnnxDataSource();
    await onnxDataSource.init();
    OnnxInferenceRepository onnxInferenceRepository = OnnxInferenceRepository(
      onnxDataSource,
    );

    // message handler
    workerReceivePort.listen((dynamic message) async {
      if (message is IndexingTask) {
        // perform indexing task
        try {
          final AssetEntity? imageAsset = await AssetEntity.fromId(
            message.assetId,
          );

          if (imageAsset == null) {
            config.mainSendPort.send(
              IndexingResult.failure(message.assetId, 'Asset not found'),
            );
            return;
          }

          final File? imageFile = await imageAsset.file;
          if (imageFile == null) {
            config.mainSendPort.send(
              IndexingResult.failure(message.assetId, 'File not found'),
            );
            return;
          }
          final Float32List embedding = await onnxInferenceRepository
              .encodeImage(imageFile);

          final IndexingResult result = IndexingResult.success(
            message.assetId,
            embedding,
          );
          config.mainSendPort.send(result);
        } catch (e, _) {
          // error throwing
          config.mainSendPort.send(
            IndexingResult.failure(message.assetId, 'Error: $e'),
          );
        }
      }
    });
  }
}

class IndexingService {
  final Queue<IndexingTask> taskQueue = Queue<IndexingTask>();

  final IndexingWorker _worker = IndexingWorker();

  final Logger _logger = loggers[LoggerName.indexingQueueService]!;

  final IStoreRepository _storeRepository;

  IndexingService({required IStoreRepository storeRepository})
    : _storeRepository = storeRepository;

  bool _isWorkerReady = false;
  bool _isProcessing = false;

  Future<void> initialize() async {
    await _worker.init();
    _isWorkerReady = true;
    _worker.onMessage.listen((message) {
      handleWorkerResult(message);
    });
  }

  void enQueue(List<String> assetIds) {
    taskQueue.addAll(assetIds.map((id) => IndexingTask(assetId: id)));
    _logger.printLog('Enqueued indexing task for image $assetIds');
  }

  void processNextTask() {
    if (!_isWorkerReady || taskQueue.isEmpty || _isProcessing) {
      return;
    }

    _isProcessing = true;
    final task = taskQueue.removeFirst();

    // send task to worker
    _logger.printLog(
      'Start processing indexing task for image ${task.assetId}',
    );
    _worker.workerSendPort?.send(task);
  }

  void handleWorkerResult(dynamic message) {
    if (message is IndexingResult) {
      if (message.embedding != null) {
        // save to db
        _storeRepository.saveImageEmbedding(
          message.assetId,
          message.embedding!,
        );
        _logger.printLog('Indexed asset ${message.assetId} successfully!');
      } else {
        // error handling
        _logger.printLog(
          "Error indexing asset ${message.assetId}: ${message.errorMessage}",
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
