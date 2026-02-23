enum EIndexingStatus { pending, processing, failed }

class IndexingJob {
  final String assetId;
  final EIndexingStatus status;
  final int attemptCount;

  IndexingJob({
    required this.assetId,
    required this.status,
    required this.attemptCount,
  });
}
