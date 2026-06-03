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

  IndexingProgress copyWith({int? total, int? processed, bool? isIndexing}) {
    return IndexingProgress(
      total: total ?? this.total,
      processed: processed ?? this.processed,
      isIndexing: isIndexing ?? this.isIndexing,
    );
  }
}
