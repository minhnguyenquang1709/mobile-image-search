import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';

abstract class IWorker {
  ReceivePort? mainReceivePort;
  SendPort? workerSendPort;
  Isolate? isolate;
  Future<void> init({
    required String textEncoderExtractedPath,
    required String imageEncoderExtractedPath,
  });
  void dispose();
  Stream<dynamic> get onMessage;
}

class WorkerSetupConfig {
  final SendPort mainSendPort;
  final RootIsolateToken rootIsolateToken;

  WorkerSetupConfig({
    required this.mainSendPort,
    required this.rootIsolateToken,
  });
}
