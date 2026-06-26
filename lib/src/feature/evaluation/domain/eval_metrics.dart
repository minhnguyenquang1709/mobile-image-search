// Pure retrieval-quality metrics.
//
// Filenames are compared by basename, case-insensitive, so a ranked path like
// `/data/foo/Cat.JPG` matches a ground-truth entry `cat.jpg`.

String _normalize(String filename) {
  final int slash = filename.lastIndexOf(RegExp(r'[\\/]'));
  final String base = slash >= 0 ? filename.substring(slash + 1) : filename;
  return base.toLowerCase();
}

Set<String> _normalizeAll(Iterable<String> names) =>
    names.map(_normalize).toSet();

/// Recall@K = (relevant items in top K) / (total relevant).
///
/// Returns 0 when there are no relevant items (callers should skip such queries
/// when averaging).
double recallAtK(List<String> ranked, Set<String> relevant, int k) {
  final Set<String> rel = _normalizeAll(relevant);
  if (rel.isEmpty) return 0;
  int hits = 0;
  for (final name in ranked.take(k)) {
    if (rel.contains(_normalize(name))) hits++;
  }
  return hits / rel.length;
}

/// 1 / rank-of-first-relevant over the full ranked list (0 if none).
double reciprocalRank(List<String> ranked, Set<String> relevant) {
  final int rank = firstHitRank(ranked, relevant);
  return rank == 0 ? 0 : 1 / rank;
}

/// 1-based rank of the first relevant item in [ranked], or 0 if none.
int firstHitRank(List<String> ranked, Set<String> relevant) {
  final Set<String> rel = _normalizeAll(relevant);
  for (int i = 0; i < ranked.length; i++) {
    if (rel.contains(_normalize(ranked[i]))) return i + 1;
  }
  return 0;
}
