import 'dart:collection';

import 'package:mobile_image_search/model/indexing_job.dart';
import 'package:mobile_image_search/utils/logger.dart';

class IndexingQueueService {
  final ListQueue<IndexingJob> _queue = ListQueue<IndexingJob>();

  static final IndexingQueueService _instance =
      IndexingQueueService._internal();

  factory IndexingQueueService() {
    return _instance;
  }

  IndexingQueueService._internal();

  ListQueue<IndexingJob> get queue => _queue;

  final Logger _logger = loggers[LoggerName.IndexingQueueService]!;

  void enqueue(IndexingJob job) {
    _queue.addLast(job);
    _logger.printLog('Enqueued job for asset ${job.assetId}');
  }

  IndexingJob? dequeue() {
    if (_queue.isNotEmpty) {
      _logger.printLog('Dequeued job for asset ${_queue.first.assetId}');
      return _queue.removeFirst();
    }
    _logger.printLog('Queue is empty, cannot dequeue');
    return null;
  }

  bool get isEmpty => _queue.isEmpty;

  int get length => _queue.length;

  void clear() {
    _queue.clear();
  }
}
