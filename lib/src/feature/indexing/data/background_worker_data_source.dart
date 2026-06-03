import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_image_search/src/constants/config_constant.dart';
import 'package:mobile_image_search/src/constants/method_param_constant.dart';
import 'package:mobile_image_search/src/feature/indexing/data/onnx_data_source.dart';
import 'package:mobile_image_search/src/feature/search/domain/model/background_isolate_command.dart';
import 'package:mobile_image_search/src/shared/domain/interface/background_worker_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/indexing_progress.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:path_provider/path_provider.dart';

/// Data source that abstract the interaction with background worker isolate for image indexing
///
/// Considering dart isolate as a server, this data source acts as a client that sends requests to the isolate and listens for responses
class BackgroundWorkerDataSource {
  // listen for message from worker isolate
  ReceivePort? _mainReceivePort;
  // send message to worker isolate
  SendPort? _workerSendPort;
  // reference to worker isolate
  Isolate? _backgroundIsolate;

  // track indexing prgress
  final StreamController<IndexingProgress> _messageController =
      StreamController.broadcast();

  IndexingProgress _currentIndexingProgress = IndexingProgress(
    total: 0,
    processed: 0,
    isIndexing: false,
  );

  // track ongoing requests
  final Map<String, Completer<dynamic>> _pendingIndexingTasks = {};
  int _taskIdCounter = 0;

  IndexingProgress get currentIndexingProgress => _currentIndexingProgress;

  String _getNextTaskId() => 'task_${_taskIdCounter++}';

  Future<void> init() async {
    // setup communication
    _mainReceivePort = ReceivePort();
    // identity of the main isolate, allows background isolate to use platform plugins
    final RootIsolateToken rootToken = RootIsolateToken.instance!;

    // prepare communication cpnfig
    final WorkerSetupConfig workerSetupConfig = WorkerSetupConfig(
      mainSendPort: _mainReceivePort!.sendPort,
      rootIsolateToken: rootToken,
    );

    // prepare model file paths
    // extract model to file system to allow bg isolate to load
    final directory = await getApplicationSupportDirectory();
    debugPrint(
      "[BackgroundWorkerDataSource] Application support directory: ${directory.path}",
    );
    final applicationSupportDirPath = directory.path;

    // copy model files from assets to file system and initialize data sources
    final textEncoderFilePath =
        '$applicationSupportDirPath${Platform.pathSeparator}${Model.textEncoderAssetPath}';
    final imageEncoderFilePath =
        '$applicationSupportDirPath${Platform.pathSeparator}${Model.imageEncoderAssetPath}';
    final bpeVocabFilePath =
        '$applicationSupportDirPath${Platform.pathSeparator}${Model.tokenizerDir}${Platform.pathSeparator}vocab.json';
    final bpeMergesFilePath =
        '$applicationSupportDirPath${Platform.pathSeparator}${Model.tokenizerDir}${Platform.pathSeparator}merges.txt';

    // check if files exit
    final textEncoderFile = File(textEncoderFilePath);
    final imageEncoderFile = File(imageEncoderFilePath);
    final bpeVocabFile = File(bpeVocabFilePath);
    final bpeMergesFile = File(bpeMergesFilePath);
    if (!await textEncoderFile.exists()) {
      final textEncoderFileData = await rootBundle.load(
        Model.textEncoderAssetPath,
      );

      // create parent directories
      await textEncoderFile.parent.create(recursive: true);

      // write to file system
      await textEncoderFile.writeAsBytes(
        textEncoderFileData.buffer.asUint8List(),
        flush: true,
      );
    }

    if (!await imageEncoderFile.exists()) {
      final imageEncoderFileData = await rootBundle.load(
        Model.imageEncoderAssetPath,
      );

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

      await bpeMergesFile.parent.create(recursive: true);

      await bpeMergesFile.writeAsBytes(
        bpeMergesFileData.buffer.asUint8List(),
        flush: true,
      );
    }

    final spawnArgs = <String, dynamic>{};
    spawnArgs[MethodParams.mainIsolateConfig] = workerSetupConfig;
    // spawnArgs[MethodParams.bpeMergesExtractedPath] = bpeMergesFilePath;
    // spawnArgs[MethodParams.bpeVocabExtractedPath] = bpeVocabFilePath;
    // spawnArgs[MethodParams.imageEncoderExtractedPath] = imageEncoderFilePath;
    // spawnArgs[MethodParams.textEncoderExtractedPath] = textEncoderFilePath;
    spawnArgs[MethodParams.applicationSupportDirPath] = directory.path;

    final isolateReadyCompleter = Completer<void>();
    _backgroundIsolate = await Isolate.spawn(_initBackgroundIsolate, spawnArgs);

    // setup message listener
    _mainReceivePort!.listen((message) {
      if (message is SendPort) {
        _workerSendPort = message;
        if (!isolateReadyCompleter.isCompleted) {
          isolateReadyCompleter.complete();
        }
      }

      // handle text encoding result
      if (message is TextEncodingResult) {
        final completer = _pendingIndexingTasks.remove(message.taskId);
        if (completer != null) {
          if (message.errorMessage != null) {
            completer.complete(
              TextEncodingResult.failure(message.taskId, message.errorMessage!),
            );
          } else {
            completer.complete(
              TextEncodingResult.success(message.taskId, message.embedding),
            );
          }
        }
      }

      // handle image encoding result
      if (message is ImageEncodingResult) {
        final completer = _pendingIndexingTasks.remove(message.taskId);
        if (completer != null) {
          if (message.errorMessage != null) {
            debugPrint(
              "[BackgroundWorkerDataSource] Image encoding error for assetId ${message.assetId}: ${message.errorMessage}",
            );
            completer.complete(
              ImageEncodingResult.failure(
                message.taskId,
                message.assetId,
                message.errorMessage!,
              ),
            );
          } else {
            debugPrint(
              "[BackgroundWorkerDataSource] Image encoding successful for assetId ${message.assetId}: ${message.errorMessage}",
            );
            completer.complete(
              ImageEncodingResult.success(
                message.taskId,
                message.assetId,
                message.embedding,
              ),
            );
          }
        }
      }

      // handle update indexing progress
      if (message is IndexingProgress) {
        _currentIndexingProgress = message;
        _messageController.add(message);
      }
    });

    await isolateReadyCompleter.future;
    debugPrint(
      "[BackgroundWorkerDataSource] Background worker isolate initialized",
    );
  }

  static Future<void> _initBackgroundIsolate(
    Map<String, dynamic> params,
  ) async {
    // extract params
    final WorkerSetupConfig workerConfig =
        params[MethodParams.mainIsolateConfig] as WorkerSetupConfig;
    // final String textEncoderExtractedPath =
    //     params[MethodParams.textEncoderExtractedPath] as String;
    // final String imageEncoderExtractedPath =
    //     params[MethodParams.imageEncoderExtractedPath] as String;
    // final String bpeVocabExtractedPath =
    //     params[MethodParams.bpeVocabExtractedPath] as String;
    // final String bpeMergesExtractedPath =
    //     params[MethodParams.bpeMergesExtractedPath] as String;
    final String applicationSupportDirPath =
        params[MethodParams.applicationSupportDirPath] as String;

    // register isolate to allow using plugins
    BackgroundIsolateBinaryMessenger.ensureInitialized(
      workerConfig.rootIsolateToken,
    );

    // set up communication channel
    final workerReceivePort = ReceivePort();
    workerConfig.mainSendPort.send(workerReceivePort.sendPort);

    // copy model files from assets to file system and initialize data sources
    final textEncoderFilePath =
        '$applicationSupportDirPath${Platform.pathSeparator}${Model.textEncoderAssetPath}';
    final imageEncoderFilePath =
        '$applicationSupportDirPath${Platform.pathSeparator}${Model.imageEncoderAssetPath}';
    final bpeVocabFilePath =
        '$applicationSupportDirPath${Platform.pathSeparator}${Model.tokenizerDir}${Platform.pathSeparator}vocab.json';
    final bpeMergesFilePath =
        '$applicationSupportDirPath${Platform.pathSeparator}${Model.tokenizerDir}${Platform.pathSeparator}merges.txt';

    // init models
    OnnxDataSource onnxDataSource = OnnxDataSource();
    await onnxDataSource.init(
      textEncoderExtractedPath: textEncoderFilePath,
      imageEncoderExtractedPath: imageEncoderFilePath,
      bpeMergesExtractedPath: bpeMergesFilePath,
      bpeVocabExtractedPath: bpeVocabFilePath,
    );

    // listen for messages from main isolate
    workerReceivePort.listen((message) async {
      // if message is text encoding request
      if (message is TextEncodingCommand) {
        try {
          final textEmbedding = await onnxDataSource.encodeText(message.query);
          workerConfig.mainSendPort.send(
            TextEncodingResult.success(message.taskId, textEmbedding),
          );
        } catch (e) {
          workerConfig.mainSendPort.send(
            TextEncodingResult.failure(message.taskId, e.toString()),
          );
        }
      }

      // if message is image encoding request
      if (message is ImageEncodingCommand) {
        debugPrint(
          "[BackgroundWorkerDataSource] Received image encoding request for assetId: ${message.assetId}",
        );
        try {
          final imageEmbedding = await onnxDataSource.encodeImage(
            message.imageBytes,
            message.title,
          );
          workerConfig.mainSendPort.send(
            ImageEncodingResult.success(
              message.taskId,
              message.assetId,
              imageEmbedding,
            ),
          );
        } catch (e) {
          workerConfig.mainSendPort.send(
            ImageEncodingResult.failure(
              message.taskId,
              message.assetId,
              e.toString(),
            ),
          );
        }
      }
    });
  }

  void dispose() {
    _backgroundIsolate?.kill(priority: Isolate.immediate);
    _backgroundIsolate = null;
    _mainReceivePort?.close();
    _mainReceivePort = null;
    _workerSendPort = null;
    _messageController.close();
  }

  /// Receive image data, send to worker isolate for encoding, and return the resulting embedding
  Future<Float32List> encodeImage(
    String assetId,
    String title,
    Uint8List imageBytes,
  ) async {
    debugPrint(
      "[BackgroundWorkerDataSource] Sending image encoding request for assetId: ${assetId}",
    );
    final id = _getNextTaskId();
    final completer = Completer<ImageEncodingResult>();

    _pendingIndexingTasks[id] = completer;

    _workerSendPort?.send(
      ImageEncodingCommand(
        taskId: id,
        assetId: assetId,
        title: title,
        imageBytes: imageBytes,
      ),
    );

    // wait for isolate to respond
    final result = await completer.future;
    return result.embedding;
  }

  Future<Float32List> encodeText(String text) async {
    final id = _getNextTaskId();
    final completer = Completer<TextEncodingResult>();

    _pendingIndexingTasks[id] = completer;

    _workerSendPort?.send(TextEncodingCommand(taskId: id, query: text));

    // yield execution until isolate responds
    final result = await completer.future;
    return result.embedding;
  }
}
