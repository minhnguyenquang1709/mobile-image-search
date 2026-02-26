import 'dart:collection';

import 'package:mobile_image_search/core/utils/logger.dart';
import 'package:mobile_image_search/feature/indexing/domain/indexing_job.dart';
import 'package:mobile_image_search/feature/indexing/domain/interface.dart';

class IndexingQueueRepository implements IIndexingQueueRepository {
  final Queue<IndexingJob> _queue = Queue<IndexingJob>();

  bool get isEmpty => _queue.isEmpty;
  int get length => _queue.length;

  final Logger _logger = loggers[LoggerName.IndexingRepository]!;

  @override
  void enqueueIndexingJob(IndexingJob job) {
    _queue.addLast(job);
    _logger.printLog('Enqueued job for asset ${job.assetId}');
  }

  @override
  IndexingJob? dequeueIndexingJob() {
    if (_queue.isNotEmpty) {
      _logger.printLog('Dequeued job for asset ${_queue.first.assetId}');
      return _queue.removeFirst();
    }
    _logger.printLog('Queue is empty, cannot dequeue');
    return null;
  }

  @override
  void clearIndexingQueue() {
    _queue.clear();
  }
}
