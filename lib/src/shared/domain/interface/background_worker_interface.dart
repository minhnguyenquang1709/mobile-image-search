import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:mobile_image_search/src/shared/domain/model/indexing_progress.dart';

abstract class IBackgroundWorkerRepository {
  /// initialize worker isolate with necessary file paths, message handlers
  Future<void> init();

  /// dispose worker isolate and resources
  void dispose();

  /// expose stream of message that the presentation layer can listen to
  Stream<IndexingProgress> get progressStream;
  IndexingProgress get currentIndexingProgress;

  /// encode text and return embedding
  Future<Float32List> encodeText(String text);

  /// encode image and return embedding
  Future<Float32List> encodeImage(Uint8List imageBytes);

  /// sync gallery changes in background
  Future<void> syncGallery();

  // /// save indexed image to vector store in background
  // Future<bool> saveImageEmbedding();

  // /// delete image embedding from vector store in background
  // Future<bool> deleteImageEmbeddings(List<String> assetIds);
}

/// Encapsulate background isolate setup config
class WorkerSetupConfig {
  final SendPort mainSendPort;
  final RootIsolateToken rootIsolateToken;

  WorkerSetupConfig({
    required this.mainSendPort,
    required this.rootIsolateToken,
  });
}
