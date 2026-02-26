enum EIndexingStatus { pending, processing, failed }

class IndexingJob {
  final String assetId;
  final EIndexingStatus status;

  IndexingJob({required this.assetId, required this.status});
}
