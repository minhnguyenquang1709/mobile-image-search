import 'package:mobile_image_search/feature/indexing/domain/indexing_job.dart';

abstract class IIndexingQueueRepository {
  void enqueueIndexingJob(IndexingJob job);
  IndexingJob? dequeueIndexingJob();

  void clearIndexingQueue();
}
