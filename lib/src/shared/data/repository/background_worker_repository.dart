import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/constants/config_constant.dart';
import 'package:mobile_image_search/src/constants/method_param_constant.dart';
import 'package:mobile_image_search/src/feature/gallery/data/gallery_data_source.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_data_source.dart';
import 'package:mobile_image_search/src/feature/indexing/data/onnx_data_source.dart';
import 'package:mobile_image_search/src/feature/search/domain/model/background_isolate_command.dart';
import 'package:mobile_image_search/src/shared/domain/interface/background_worker_interface.dart';
import 'package:path_provider/path_provider.dart';

class BackgroundWorkerRepo implements IBackgroundWorkerRepository {
  // listen for message from worker isolate
  ReceivePort? _mainReceivePort;
  // send message to worker isolate
  SendPort? _workerSendPort;
  // reference to worker isolate
  Isolate? _backgroundIsolate;

  final StreamController _messageController = StreamController.broadcast();

  // track ongoing requests
  final Map<String, Completer<dynamic>> _pendingTasks = {};
  int _taskIdCounter = 0;

  String _getNextTaskId() => 'task_${_taskIdCounter++}';

  @override
  Stream get onMessage => _messageController.stream;

  @override
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
    final textEncoderFilePath =
        '${directory.path}${Platform.pathSeparator}${Model.textEncoderAssetPath}';
    final imageEncoderFilePath =
        '${directory.path}${Platform.pathSeparator}${Model.imageEncoderAssetPath}';
    final bpeVocabFilePath =
        '${directory.path}${Platform.pathSeparator}${Model.tokenizerDir}${Platform.pathSeparator}vocab.json';
    final bpeMergesFilePath =
        '${directory.path}${Platform.pathSeparator}${Model.tokenizerDir}${Platform.pathSeparator}merges.txt';

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
    spawnArgs[MethodParams.bpeMergesExtractedPath] = bpeMergesFilePath;
    spawnArgs[MethodParams.bpeVocabExtractedPath] = bpeVocabFilePath;
    spawnArgs[MethodParams.imageEncoderExtractedPath] = imageEncoderFilePath;
    spawnArgs[MethodParams.textEncoderExtractedPath] = textEncoderFilePath;

    _backgroundIsolate = await Isolate.spawn(_initBackgroundIsolate, spawnArgs);

    // setup message listener
    _mainReceivePort!.listen((message) {
      if (message is SendPort) {
        _workerSendPort = message;
      }

      // handle text encoding result
      if (message is TextEncodingResult) {}
    });
  }

  @override
  void dispose() {
    _backgroundIsolate?.kill(priority: Isolate.immediate);
    _backgroundIsolate = null;
    _mainReceivePort?.close();
    _mainReceivePort = null;
    _workerSendPort = null;
    _messageController.close();
  }

  @override
  Future<Float32List> encodeImage(Uint8List imageBytes) {
    // TODO: implement encodeImage
    throw UnimplementedError();
  }

  @override
  Future<Float32List> encodeText(String text) async {
    final id = _getNextTaskId();
    final completer = Completer<TextEncodingResult>();

    _pendingTasks[id] = completer;

    _workerSendPort?.send(TextEncodingCommand(taskId: id, query: text));

    // wait for isolate to respond
    final result = await completer.future;
    return result.embedding;
  }

  @override
  Future<void> syncGallery() {
    // TODO: implement syncGallery
    throw UnimplementedError();
  }

  static Future<void> _initBackgroundIsolate(
    Map<String, dynamic> params,
  ) async {
    // extract params
    final WorkerSetupConfig workerConfig =
        params[MethodParams.mainIsolateConfig] as WorkerSetupConfig;
    final String textEncoderExtractedPath =
        params[MethodParams.textEncoderExtractedPath] as String;
    final String imageEncoderExtractedPath =
        params[MethodParams.imageEncoderExtractedPath] as String;
    final String bpeVocabExtractedPath =
        params[MethodParams.bpeVocabExtractedPath] as String;
    final String bpeMergesExtractedPath =
        params[MethodParams.bpeMergesExtractedPath] as String;

    // register isolate to allow using plugins
    BackgroundIsolateBinaryMessenger.ensureInitialized(
      workerConfig.rootIsolateToken,
    );

    // set up communication channel
    final workerReceivePort = ReceivePort();
    workerConfig.mainSendPort.send(workerReceivePort.sendPort);

    // init models
    OnnxDataSource onnxDataSource = OnnxDataSource();
    await onnxDataSource.init(
      textEncoderExtractedPath: textEncoderExtractedPath,
      imageEncoderExtractedPath: imageEncoderExtractedPath,
      bpeMergesExtractedPath: bpeMergesExtractedPath,
      bpeVocabExtractedPath: bpeVocabExtractedPath,
    );

    // init vector store
    ObjectBoxStoreDataSource objectBoxStoreDataSource =
        ObjectBoxStoreDataSource();
    await objectBoxStoreDataSource.init();

    // init gallery data source
    GalleryDataSource galleryDataSource = GalleryDataSource();

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
      if (message is ImageEncodingCommand) {}
    });
  }
}

final backgroundWorkerRepoProvider = FutureProvider((ref) async {
  final repo = BackgroundWorkerRepo();
  await repo.init();
  return repo;
});
