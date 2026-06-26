import 'dart:isolate';

import 'package:flutter/services.dart';

/// Encapsulate background isolate setup config
class WorkerSetupConfig {
  final SendPort mainSendPort;
  final RootIsolateToken rootIsolateToken;

  /// Reference to the main isolate's ObjectBox store, so the worker can attach
  /// to the same underlying store via [Store.fromReference] and run DB writes
  /// off the UI isolate.
  final ByteData storeReference;

  WorkerSetupConfig({
    required this.mainSendPort,
    required this.rootIsolateToken,
    required this.storeReference,
  });
}
