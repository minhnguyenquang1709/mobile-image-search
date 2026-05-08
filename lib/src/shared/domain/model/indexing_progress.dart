class IndexingProgress {
  final int total;
  final int processed;
  final bool isIndexing;

  IndexingProgress({
    required this.total,
    required this.processed,
    required this.isIndexing,
  });

  double get progress => total == 0 ? 0 : processed / total;
}
