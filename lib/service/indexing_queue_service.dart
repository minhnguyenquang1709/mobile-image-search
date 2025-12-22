import 'dart:collection';

import 'package:mobile_image_search/model/indexing_job.dart';

class IndexingQueueService {
  final ListQueue<IndexingJob> _queue = ListQueue<IndexingJob>();

  static final IndexingQueueService _instance =
      IndexingQueueService._internal();

  factory IndexingQueueService() {
    return _instance;
  }

  IndexingQueueService._internal();

  void enqueue(IndexingJob job) {
    _queue.addLast(job);
  }

  IndexingJob? dequeue() {
    if (_queue.isNotEmpty) {
      return _queue.removeFirst();
    }
    return null;
  }

  bool get isEmpty => _queue.isEmpty;

  int get length => _queue.length;

  void clear() {
    _queue.clear();
  }
}
