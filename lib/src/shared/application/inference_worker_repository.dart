import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/constants/config_constant.dart';
import 'package:mobile_image_search/src/constants/method_param_constant.dart';
import 'package:mobile_image_search/src/feature/indexing/data/ai_inference_repository.dart';
import 'package:mobile_image_search/src/feature/indexing/data/onnx_data_source.dart';
import 'package:mobile_image_search/src/shared/domain/interface/background_worker_interface.dart';
import 'package:mobile_image_search/src/feature/indexing/domain/indexing_model.dart';
import 'package:mobile_image_search/src/shared/domain/model/media.dart';
import 'package:mobile_image_search/src/shared/domain/model/search_model.dart';
import 'package:mobile_image_search/src/utils/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

final Logger _logger = loggers[LoggerName.inferenceWorker]!;

/// Represent a background worker, the class instance itself is hosted on main isolate
///
/// `_initWorker` is executed on worker isolate
class AiInferenceWorkerRepository extends IInferenceWorkerRepository {
  final Completer<void> _initCompleter = Completer<void>();

  final Map<String, Completer<dynamic>> _taskResolvers = {};

  int _taskIdCounter = 0;

  // stream for receiving messages from worker
  final StreamController<dynamic> _messageController =
      StreamController.broadcast();

  void _resolveTask(String taskId, dynamic result) {
    if (_taskResolvers.containsKey(taskId)) {
      final completer = _taskResolvers.remove(taskId)!;
      if (!completer.isCompleted) {
        completer.complete();
      }
    } else {
      _logger.printLog('No completer found for taskId: $taskId');
    }
  }

  String _generateTaskId() => "task_${_taskIdCounter++}";

  @override
  Stream get onMessage => _messageController.stream;

  @override
  Future<EncodeTextResult> encodeText(String text) {
    final String taskId = _generateTaskId();
    final Completer<EncodeTextResult> completer = Completer();

    _taskResolvers[taskId] = completer;
    workerSendPort?.send(EncodeTextTask(taskId: taskId, query: text));

    return completer.future;
  }

  @override
  Future<IndexingResult> indexImage(Media media) {
    final String taskId = _generateTaskId();
    final Completer<IndexingResult> completer = Completer();

    _taskResolvers[taskId] = completer;
    workerSendPort?.send(IndexingTask(media: media, taskId: taskId));

    return completer.future;
  }

  @override
  void dispose() {
    isolate?.kill(priority: Isolate.immediate);
    isolate = null;
    mainReceivePort?.close();
    mainReceivePort = null;
    workerSendPort = null;
    _messageController.close();
    _taskResolvers.clear();
  }

  @override
  Future<void> init(Map<String, dynamic> params) async {
    mainReceivePort = ReceivePort();

    final RootIsolateToken rootToken = RootIsolateToken.instance!;

    final workerSetupConfig = WorkerSetupConfig(
      mainSendPort: mainReceivePort!.sendPort,
      rootIsolateToken: rootToken,
    );

    final String textEncoderExtractedPath =
        params[AiInferenceParams.textEncoderExtractedPath];
    final String imageEncoderExtractedPath =
        params[AiInferenceParams.imageEncoderExtractedPath];
    final String bpeVocabExtractedPath =
        params[AiInferenceParams.bpeVocabExtractedPath];
    final String bpeMergesExtractedPath =
        params[AiInferenceParams.bpeMergesExtractedPath];

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
        _initCompleter.complete();
      } else if (message is IndexingResult) {
        _resolveTask(message.taskId, message);
      } else if (message is EncodeTextResult) {
        _resolveTask(message.taskId, message);

        // notify listeners (UI controller)
        _messageController.add(message);
      }
    });

    // finish initialization
    await _initCompleter.future;
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

    // worker isolate-side message handler
    workerReceivePort.listen((dynamic message) async {
      if (message is IndexingTask) {
        // perform indexing task
        try {
          final AssetEntity? imageAsset = await AssetEntity.fromId(
            message.media.assetId,
          );

          if (imageAsset == null) {
            workerConfig.mainSendPort.send(
              IndexingResult.failure(
                message.taskId,
                message.media,
                'Asset not found',
              ),
            );
            return;
          }

          final File? imageFile = await imageAsset.file;
          if (imageFile == null) {
            workerConfig.mainSendPort.send(
              IndexingResult.failure(
                message.taskId,
                message.media,
                'File not found',
              ),
            );
            return;
          }
          final Float32List embedding = await onnxInferenceRepository
              .encodeImage(imageFile);

          final IndexingResult result = IndexingResult.success(
            message.taskId,
            message.media,
            embedding,
          );
          workerConfig.mainSendPort.send(result);
        } catch (e, _) {
          // error throwing
          workerConfig.mainSendPort.send(
            IndexingResult.failure(message.taskId, message.media, 'Error: $e'),
          );
        }
      }

      if (message is EncodeTextTask) {
        try {
          // perform text encoding task
          final Float32List embedding = await onnxInferenceRepository
              .encodeText(message.query);
          final result = EncodeTextResult.success(message.taskId, embedding);
          workerConfig.mainSendPort.send(result);
        } catch (e, _) {
          workerConfig.mainSendPort.send(
            EncodeTextResult.failure(message.taskId, 'Error: $e'),
          );
        }
      }
    });
  }
}

final aiInferenceWorkerRepoProvider = FutureProvider<AiInferenceWorkerRepository>((
  ref,
) async {
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
    _logger.printLog('Extracting text encoder model to $textEncoderFilePath');
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

  final worker = AiInferenceWorkerRepository();
  await worker.init({
    AiInferenceParams.textEncoderExtractedPath: textEncoderFilePath,
    AiInferenceParams.imageEncoderExtractedPath: imageEncoderFilePath,
    AiInferenceParams.bpeVocabExtractedPath: bpeVocabFilePath,
    AiInferenceParams.bpeMergesExtractedPath: bpeMergesFilePath,
  });

  ref.onDispose(() => worker.dispose());
  return worker;
});
