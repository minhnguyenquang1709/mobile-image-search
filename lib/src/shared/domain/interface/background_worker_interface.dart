import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:mobile_image_search/src/feature/indexing/domain/indexing_model.dart';
import 'package:mobile_image_search/src/shared/domain/model/media.dart';
import 'package:mobile_image_search/src/shared/domain/model/search_model.dart';

abstract class IInferenceWorkerRepository {
  ReceivePort? mainReceivePort;
  SendPort? workerSendPort;
  Isolate? isolate;
  Future<void> init(Map<String, dynamic> params);
  void dispose();

  /// stream for receiving messages from worker
  Stream<dynamic> get onMessage;

  /// encode text and return embedding
  Future<EncodeTextResult> encodeText(String text);

  ///
  Future<IndexingResult> indexImage(Media media);
}

class WorkerSetupConfig {
  final SendPort mainSendPort;
  final RootIsolateToken rootIsolateToken;

  WorkerSetupConfig({
    required this.mainSendPort,
    required this.rootIsolateToken,
  });
}
