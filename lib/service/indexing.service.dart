import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/core/utils/logger.dart';

class IndexingService {
  final Logger _logger = loggers[LoggerName.IndexingQueueService]!;

  void startProcessingQueue
}

final indexingServiceProvider = Provider((ref) => IndexingService());
