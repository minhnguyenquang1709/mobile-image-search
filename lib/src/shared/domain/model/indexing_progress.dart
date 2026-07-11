enum EIndexingPhase { idle, fetchingMedia, diffing, indexing }

class IndexingProgress {
  final int total;
  final int processed;
  final bool isIndexing;
  final EIndexingPhase phase;

  IndexingProgress({
    required this.total,
    required this.processed,
    required this.isIndexing,
    this.phase = EIndexingPhase.idle,
  });

  double get progress => total == 0 ? 0 : processed / total;

  IndexingProgress copyWith({
    int? total,
    int? processed,
    bool? isIndexing,
    EIndexingPhase? phase,
  }) {
    return IndexingProgress(
      total: total ?? this.total,
      processed: processed ?? this.processed,
      isIndexing: isIndexing ?? this.isIndexing,
      phase: phase ?? this.phase,
    );
  }
}
