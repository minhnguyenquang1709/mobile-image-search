import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/constants/common_constant.dart';
import 'package:mobile_image_search/src/constants/config_constant.dart';
import 'package:mobile_image_search/src/constants/method_param_constant.dart';
import 'package:mobile_image_search/src/core/platform_image_method_channel.dart';
import 'package:mobile_image_search/src/feature/gallery/data/gallery_data_source.dart';
import 'package:mobile_image_search/src/feature/indexing/data/image_objectbox_model.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_data_source.dart';
import 'package:mobile_image_search/src/feature/indexing/data/onnx_data_source.dart';
import 'package:mobile_image_search/src/feature/search/domain/model/background_isolate_command.dart';
import 'package:mobile_image_search/src/shared/domain/interface/background_worker_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/indexing_progress.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:mobile_image_search/src/utils/logger.dart';
import 'package:mobile_image_search/src/utils/media_processing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

class BackgroundWorkerRepo implements IBackgroundWorkerRepository {
  // listen for message from worker isolate
  ReceivePort? _mainReceivePort;
  // send message to worker isolate
  SendPort? _workerSendPort;
  // reference to worker isolate
  Isolate? _backgroundIsolate;

  // track indexing prgress
  final StreamController<IndexingProgress> _messageController =
      StreamController.broadcast();

  @override
  Stream<IndexingProgress> get progressStream => _messageController.stream;

  // track ongoing requests
  final Map<String, Completer<dynamic>> _pendingIndexingTasks = {};
  int _taskIdCounter = 0;

  String _getNextTaskId() => 'task_${_taskIdCounter++}';

  IndexingProgress _currentIndexingProgress = IndexingProgress(
    total: 0,
    processed: 0,
    isIndexing: false,
  );

  @override
  IndexingProgress get currentIndexingProgress => _currentIndexingProgress;

  static final Logger _logger = loggers[LoggerName.backgroundWorkerRepo]!;

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
            completer.complete(
              ImageEncodingResult.failure(
                message.taskId,
                message.assetId,
                message.errorMessage!,
              ),
            );
          } else {
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
    _logger.printLog("Background worker isolate initialized");
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
  Future<Float32List> encodeImage(Uint8List imageBytes) async {
    final id = _getNextTaskId();
    final completer = Completer<ImageEncodingResult>();

    _pendingIndexingTasks[id] = completer;

    _workerSendPort?.send(ImageEncodingCommand(taskId: id, assetId: id));

    // wait for isolate to respond
    final result = await completer.future;
    return result.embedding;
  }

  @override
  Future<Float32List> encodeText(String text) async {
    final id = _getNextTaskId();
    final completer = Completer<TextEncodingResult>();

    _pendingIndexingTasks[id] = completer;

    _workerSendPort?.send(TextEncodingCommand(taskId: id, query: text));

    // yield execution until isolate responds
    final result = await completer.future;
    return result.embedding;
  }

  /// Send command to background isolate to start the sync process
  @override
  Future<void> syncGallery() async {
    // create task
    _workerSendPort?.send(ScanGalleryCommand());
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

    // init vector store
    ObjectBoxStoreDataSource objectBoxStoreDataSource =
        ObjectBoxStoreDataSource();
    await objectBoxStoreDataSource.init();

    // init gallery data source
    MediaPlatformChannel mediaPlatformChannel = MediaPlatformChannel();
    GalleryDataSource galleryDataSource = GalleryDataSource(
      mediaPlatformChannel,
    );

    Queue<MediaAsset> pendingIndexingAssetQueue = Queue();

    bool isIndexingQueueProcessing = false;

    IndexingProgress currentIndexingProgress = IndexingProgress(
      total: 0,
      processed: 0,
      isIndexing: false,
    );

    Future<void> indexNextImage() async {
      if (isIndexingQueueProcessing) {
        return;
      }

      isIndexingQueueProcessing = true;

      currentIndexingProgress = IndexingProgress(
        total: currentIndexingProgress.total,
        processed: currentIndexingProgress.processed,
        isIndexing: false,
      );
      workerConfig.mainSendPort.send(currentIndexingProgress);
      while (pendingIndexingAssetQueue.isNotEmpty) {
        final mediaAsset = pendingIndexingAssetQueue.removeFirst();

        // _logger.printLog("Start indexing image ${mediaAsset.title}");

        try {
          final imageEmbedding = await onnxDataSource.encodeImage(mediaAsset);

          // measure saving embedding to vector store time
          final dbTask = TimelineTask()
            ..start("Save Image Embedding to Vector Store");

          // FAST
          // save to vector store
          await objectBoxStoreDataSource.saveImageEmbedding(
            mediaAsset,
            imageEmbedding,
          );
          // END FAST
          dbTask.finish();
        } catch (e) {
          rethrow;
        }

        // update progress
        currentIndexingProgress = IndexingProgress(
          total: currentIndexingProgress.total,
          processed: currentIndexingProgress.processed + 1,
          isIndexing: true,
        );
        workerConfig.mainSendPort.send(currentIndexingProgress);

        _logger.printLog(
          "Finished indexing image ${mediaAsset.title}, id: ${mediaAsset.assetId}",
        );
      }

      isIndexingQueueProcessing = false;

      currentIndexingProgress = IndexingProgress(
        total: currentIndexingProgress.total,
        processed: currentIndexingProgress.processed,
        isIndexing: false,
      );
      workerConfig.mainSendPort.send(currentIndexingProgress);
    }

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

      // if message is gallery sync request
      if (message is ScanGalleryCommand) {
        _logger.printLog("Start gallery sync process in background isolate");
        final List<MediaAsset> pendingIndexingAssetList = [];
        final List<String> pendingDeleteAssetIdList = [];

        // diffing: scan gallery and compare with indexed assets in vector store to find new/updated/deleted assets
        final List<AssetEntity> allGalleryAssetEntities =
            await galleryDataSource.getAllImages();
        final List<MediaAsset> allGalleryMediaAssets = allGalleryAssetEntities
            .map((asset) {
              return toMediaAsset(asset);
            })
            .toList();

        final imageBox = objectBoxStoreDataSource.store.box<ImageObjectBox>();
        final List<ImageObjectBox> allIndexedImages = imageBox.getAll();
        final Map<String, MediaAsset> indexedImagesMap = {
          // for (final indexedImage in allIndexedImages)
          //   indexedImage.assetId: MediaAsset(
          //     assetId: indexedImage.assetId,
          //     title: indexedImage.title,
          //     createDateTime: indexedImage.createdAt,
          //     modifiedDateTime: indexedImage.modifiedAt,
          //     mediaType: EMediaType.image,
          //     width: null,
          //     height: null,
          //     format: null,
          //   ),
        };

        for (final galleryImage in allGalleryMediaAssets) {
          final indexedImage = indexedImagesMap[galleryImage.assetId];

          if (indexedImage == null) {
            // new image
            pendingIndexingAssetList.add(galleryImage);
          } else {
            // existing image, check if modified
            if (galleryImage.modifiedDateTime.isAfter(
              indexedImage.modifiedDateTime,
            )) {
              pendingIndexingAssetList.add(galleryImage);
            }
          }

          indexedImagesMap.remove(galleryImage.assetId);
        }

        // add to queue
        pendingIndexingAssetQueue.addAll(pendingIndexingAssetList);

        // remaining items in indexedImagesMap are meant to be deleted from database
        pendingDeleteAssetIdList.addAll(indexedImagesMap.keys);

        // start processing queue
        currentIndexingProgress = IndexingProgress(
          total: pendingIndexingAssetQueue.length,
          processed: 0,
          isIndexing: true,
        );

        _logger.printLog(
          "Indexing process started. ${pendingIndexingAssetQueue.length} images to index, ${pendingDeleteAssetIdList.length} images to delete from index.",
        );
        await indexNextImage();
      }
    });
  }
}

final backgroundWorkerRepoProvider = FutureProvider((ref) async {
  final repo = BackgroundWorkerRepo();
  await repo.init();
  return repo;
});
