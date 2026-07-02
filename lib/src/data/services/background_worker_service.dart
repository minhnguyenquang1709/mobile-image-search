import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_image_search/objectbox.g.dart';
import 'package:mobile_image_search/src/core/constants/config_constant.dart';
import 'package:mobile_image_search/src/core/constants/method_param_constant.dart';
import 'package:mobile_image_search/src/data/services/onnx_service.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_image_embedding.dart';
import 'package:mobile_image_search/src/feature/search/domain/background_isolate_command.dart';
import 'package:mobile_image_search/src/shared/domain/interface/background_worker_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/indexing_progress.dart';
import 'package:photo_manager/photo_manager.dart';

/// Service that abstract the interaction with background worker isolate for image indexing
///
/// A dart isolate is a separate thread of execution that does not share memory with the main isolate.
/// Handle heavy computation in the background isolate to avoid UI jank
///
/// Considering the background dart isolate as a server, this class acts as a client that sends requests to the isolate and listens for responses
class BackgroundWorkerService {
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

  /// Progress updates emitted by the worker isolate while it indexes.
  Stream<IndexingProgress> get progressStream => _messageController.stream;

  String _getNextTaskId() => 'task_${_taskIdCounter++}';

  /// Ask the worker isolate to run the gallery indexing pipeline.
  void startIndexing() {
    _workerSendPort?.send(StartIndexingCommand(taskId: _getNextTaskId()));
  }

  Future<void> init({
    required String textEncoderPath,
    required String imageEncoderPath,
    required String vocabPath,
    required String mergesPath,
    required ByteData storeReference,
  }) async {
    // setup communication
    _mainReceivePort = ReceivePort();
    // identity of the main isolate, allows background isolate to use platform plugins
    final RootIsolateToken rootToken = RootIsolateToken.instance!;

    final WorkerSetupConfig workerSetupConfig = WorkerSetupConfig(
      mainSendPort: _mainReceivePort!.sendPort,
      rootIsolateToken: rootToken,
      storeReference: storeReference,
    );

    final spawnArgs = <String, dynamic>{};
    spawnArgs[MethodParams.mainIsolateConfig] = workerSetupConfig;
    spawnArgs[MethodParams.textEncoderExtractedPath] = textEncoderPath;
    spawnArgs[MethodParams.imageEncoderExtractedPath] = imageEncoderPath;
    spawnArgs[MethodParams.bpeVocabExtractedPath] = vocabPath;
    spawnArgs[MethodParams.bpeMergesExtractedPath] = mergesPath;

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
              "[BackgroundWorkerService] Image encoding error for assetId ${message.assetId}: ${message.errorMessage}",
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
              "[BackgroundWorkerService] Image encoding successful for assetId ${message.assetId}: ${message.errorMessage}",
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
      "[BackgroundWorkerService] Background worker isolate initialized",
    );
  }

  static Future<void> _initBackgroundIsolate(
    Map<String, dynamic> params,
  ) async {
    final WorkerSetupConfig workerConfig =
        params[MethodParams.mainIsolateConfig] as WorkerSetupConfig;
    final String textEncoderPath =
        params[MethodParams.textEncoderExtractedPath] as String;
    final String imageEncoderPath =
        params[MethodParams.imageEncoderExtractedPath] as String;
    final String vocabPath =
        params[MethodParams.bpeVocabExtractedPath] as String;
    final String mergesPath =
        params[MethodParams.bpeMergesExtractedPath] as String;

    // register isolate to allow using plugins
    BackgroundIsolateBinaryMessenger.ensureInitialized(
      workerConfig.rootIsolateToken,
    );

    // set up communication channel
    final workerReceivePort = ReceivePort();
    workerConfig.mainSendPort.send(workerReceivePort.sendPort);

    // init models with pre-extracted file paths from AssetLoader
    OnnxService onnxRuntimeService = OnnxService();
    await onnxRuntimeService.init(
      textEncoderExtractedPath: textEncoderPath,
      imageEncoderExtractedPath: imageEncoderPath,
      bpeMergesExtractedPath: mergesPath,
      bpeVocabExtractedPath: vocabPath,
    );

    // attach to the main isolate's ObjectBox store so DB reads/writes run here
    final Store store = Store.fromReference(
      getObjectBoxModel(),
      workerConfig.storeReference,
    );

    // listen for messages from main isolate
    workerReceivePort.listen((message) async {
      // if message is text encoding request
      if (message is TextEncodingCommand) {
        try {
          final textEmbedding = await onnxRuntimeService.encodeText(
            message.query,
          );
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
          "[BackgroundWorkerService] Received image encoding request for assetId: ${message.assetId}",
        );
        try {
          final imageEmbedding = await onnxRuntimeService
              .encodeImageLetterboxing(message.imageBytes);
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

      // start device gallery indexing
      if (message is StartIndexingCommand) {
        await _runGalleryIndexing(
          store,
          onnxRuntimeService,
          workerConfig.mainSendPort,
        );
      }
    });
  }

  static Future<void> _runGalleryIndexing(
    Store store,
    OnnxService onnxDataSource,
    SendPort mainSendPort,
  ) async {
    debugPrint(
      "[BackgroundWorkerService] Starting gallery indexing process...",
    );

    IndexingProgress progress = IndexingProgress(
      total: 0,
      processed: 0,
      isIndexing: true,
    );
    mainSendPort.send(progress);

    final imageEmbeddingBox = store.box<ObjectBoxImageEmbedding>();

    try {
      // diffing by metadata
      debugPrint("[BackgroundWorkerService] Read all media from device...");

      // fetch all device media assets
      final List<AssetEntity> assetEntities = [];
      final FilterOptionGroup filterOptions = FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.updateDate, asc: false),
        ],
      );
      filterOptions.setOption(
        AssetType.image,
        const FilterOption(needTitle: true),
      );
      filterOptions.setOption(
        AssetType.video,
        const FilterOption(needTitle: true),
      );
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true, // returns only one root album that contains all media
        filterOption: filterOptions,
      );

      if (albums.isEmpty) {}

      for (final album in albums) {
        debugPrint(
          "[BackgroundWorkerService] Fetching assets from album: ${album.name}, id: ${album.id}",
        );
        final int assetCount = await album.assetCountAsync;
        if (assetCount > 0) {
          final assets = await album.getAssetListRange(
            start: 0,
            end: assetCount,
          );

          assetEntities.addAll(assets);
        }
      }

      debugPrint(
        "[BackgroundWorkerService] Get all indexed media from database...",
      );
      final List<ObjectBoxImageEmbedding> indexedMediaList =
          await imageEmbeddingBox.getAllAsync();
      final Map<String, ObjectBoxImageEmbedding> indexedMediaMap = {
        for (var item in indexedMediaList) item.assetId: item,
      };

      final List<AssetEntity> assetsToIndex = [];

      debugPrint(
        "[BackgroundWorkerService] Start diffing gallery media with indexed media...",
      );
      for (final assetEntity in assetEntities) {
        final indexedMedia = indexedMediaMap[assetEntity.id];
        if (indexedMedia == null) {
          // new asset, need indexing
          assetsToIndex.add(assetEntity);
        } else {
          // existing asset, check for modification
          if (assetEntity.modifiedDateTime.isAfter(
            indexedMedia.mediaModifiedAt,
          )) {
            // asset modified, need re-indexing
            assetsToIndex.add(assetEntity);
          }
        }
        indexedMediaMap.remove(assetEntity.id);
      }

      final List<String> assetIdsToDelete = indexedMediaMap.keys.toList();
      debugPrint(
        "[BackgroundWorkerService] Gallery diffing completed. ${assetsToIndex.length} assets to index, ${assetIdsToDelete.length} assets to delete from index.",
      );

      // delete removed assets from index
      bool isDeletionSuccess = false;
      if (assetIdsToDelete.isNotEmpty) {
        Query<ObjectBoxImageEmbedding> deleteQuery = imageEmbeddingBox
            .query(ObjectBoxImageEmbedding_.assetId.oneOf(assetIdsToDelete))
            .build();
        List<ObjectBoxImageEmbedding> embeddingsToDelete = deleteQuery.find();
        if (embeddingsToDelete.isNotEmpty) {
          int removedCount = await deleteQuery.removeAsync();
          isDeletionSuccess = removedCount == embeddingsToDelete.length;
        } else {
          isDeletionSuccess = true;
        }
      } else {
        isDeletionSuccess = true;
      }
      if (!isDeletionSuccess) {
        debugPrint(
          "[BackgroundWorkerService] Warning: Not all removed assets were deleted from database",
        );
        throw Exception("Failed to delete removed assets from index");
      }

      // start indexing
      progress = IndexingProgress(
        total: assetsToIndex.length,
        processed: 0,
        isIndexing: true,
      );
      mainSendPort.send(progress);

      final ThumbnailOption thumbnailOption = ThumbnailOption(
        size: ThumbnailSize.square(Model.specs.imageSize),
      );
      for (final assetEntity in assetsToIndex) {
        // get asset entity

        // read image thumbnail bytes
        Uint8List? thumbnailBytes = await assetEntity.thumbnailDataWithOption(
          thumbnailOption,
        );
        if (thumbnailBytes == null) {
          debugPrint(
            "[BackgroundWorkerService] Warning: Failed to read thumbnail for assetId ${assetEntity.id}, skipping indexing for this asset",
          );
          continue;
        }

        try {
          // generate embedding (ONNX runs in this same worker isolate)
          final embedding = await onnxDataSource.encodeImageLetterboxing(
            thumbnailBytes,
          );

          // save to database
          final imageEmbedding = ObjectBoxImageEmbedding(
            assetId: assetEntity.id,
            title: assetEntity.title!,
            mediaType: assetEntity.type == AssetType.video ? 1 : 0,
            duration: assetEntity.duration,
            embedding: embedding,
            mediaCreatedAt: assetEntity.createDateTime,
            mediaModifiedAt: assetEntity.modifiedDateTime,
          );
          await imageEmbeddingBox.putAsync(imageEmbedding);
          debugPrint(
            "[BackgroundWorkerService] Saved embedding for ${assetEntity.id} to database",
          );

          progress = progress.copyWith(
            processed: progress.processed + 1,
            isIndexing: true,
          );
          mainSendPort.send(progress);
        } catch (e) {
          debugPrint(
            "[BackgroundWorkerService] Error generating/saving embedding for ${assetEntity.id} ${assetEntity.title}: $e",
          );
        }
      }
    } catch (e) {
      debugPrint("[BackgroundWorkerService] Indexing failed: $e");
    } finally {
      progress = IndexingProgress(
        total: progress.total,
        processed: progress.processed,
        isIndexing: false,
      );
      mainSendPort.send(progress);
    }
  }

  void dispose() {
    _backgroundIsolate?.kill(priority: Isolate.immediate);
    _backgroundIsolate = null;
    _mainReceivePort?.close();
    _mainReceivePort = null;
    _workerSendPort = null;
    _messageController.close();
  }

  /// receive image data, send to worker isolate for encoding, and return the resulting embedding
  Future<Float32List> encodeImage(
    String assetId,
    String title,
    Uint8List imageBytes,
  ) async {
    debugPrint(
      "[BackgroundWorkerService] Sending image encoding request for assetId: $assetId",
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
