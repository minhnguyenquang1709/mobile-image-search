import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/core/infra/background_worker_interface.dart';
import 'package:mobile_image_search/core/utils/logger.dart';
import 'package:mobile_image_search/feature/indexing/domain/indexing_model.dart';

class IndexingWorker
    implements IBackgroundWorker<IndexingTask, IndexingResult> {
  final Queue<IndexingTask> taskQueue = Queue();
  final StreamController<IndexingResult> _streamController =
      StreamController<IndexingResult>();

  @override
  Stream<IndexingResult> get resultStream => _streamController.stream;

  @override
  Future<void> init() {
    // TODO: implement init
    throw UnimplementedError();
  }

  @override
  void enqueueTask(IndexingTask task) {
    // TODO: implement enqueueTask
  }

  @override
  void dispose() {
    taskQueue.clear();
    _streamController.close();
  }
}

class IndexingService {
  final IndexingWorker _worker = IndexingWorker();

  final Logger _logger = loggers[LoggerName.indexingQueueService]!;
}

final indexingServiceProvider = Provider((ref) => IndexingService());
