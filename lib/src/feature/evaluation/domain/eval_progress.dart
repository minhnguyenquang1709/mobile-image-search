/// Phase of an evaluation run (mirrors the spirit of IndexingProgress).
enum EvalPhase {
  idle,
  loading,
  indexing,
  loadingEmbeddings,
  searching,
  done,
  error,
}

class EvalProgress {
  final EvalPhase phase;
  final int current;
  final int total;

  const EvalProgress({
    this.phase = EvalPhase.idle,
    this.current = 0,
    this.total = 0,
  });

  EvalProgress copyWith({EvalPhase? phase, int? current, int? total}) {
    return EvalProgress(
      phase: phase ?? this.phase,
      current: current ?? this.current,
      total: total ?? this.total,
    );
  }
}
