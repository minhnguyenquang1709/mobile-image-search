/// Per-query evaluation result.
class QueryEvalResult {
  final String query;
  final List<String> rankedTop10;
  final double r1;
  final double r5;
  final double r10;
  final double rr;
  final int firstHitRank; // 0 = no relevant item retrieved

  QueryEvalResult({
    required this.query,
    required this.rankedTop10,
    required this.r1,
    required this.r5,
    required this.r10,
    required this.rr,
    required this.firstHitRank,
  });

  Map<String, dynamic> toJson() => {
    'query': query,
    'rankedTop10': rankedTop10,
    'r1': r1,
    'r5': r5,
    'r10': r10,
    'rr': rr,
    'firstHitRank': firstHitRank,
  };
}

/// Full report of a single evaluation run: retrieval quality + latency +
/// resource footprint.
class EvaluationReport {
  final String datasetName;
  final int imageCount;
  final int queryCount;
  final DateTime timestamp;

  // retrieval quality
  final double meanRecallAt1;
  final double meanRecallAt5;
  final double meanRecallAt10;
  final double mrr;

  // latency (milliseconds)
  final int totalIndexingMs;
  final double meanIndexingMsPerImage;
  final int embeddingLoadMs;
  final int firstQueryWarmupMs;
  final int totalSearchMs;
  final double meanSearchMsPerQuery;
  final double meanEncodeTextMs;
  final double meanAnnQueryMs;

  // footprint (bytes)
  final int modelSizeBytes;
  final int vectorStoreSizeBytes;
  final int peakRssIndexingBytes;
  final int peakRssSearchBytes;

  final List<QueryEvalResult> perQuery;

  EvaluationReport({
    required this.datasetName,
    required this.imageCount,
    required this.queryCount,
    required this.timestamp,
    required this.meanRecallAt1,
    required this.meanRecallAt5,
    required this.meanRecallAt10,
    required this.mrr,
    required this.totalIndexingMs,
    required this.meanIndexingMsPerImage,
    required this.embeddingLoadMs,
    required this.firstQueryWarmupMs,
    required this.totalSearchMs,
    required this.meanSearchMsPerQuery,
    required this.meanEncodeTextMs,
    required this.meanAnnQueryMs,
    required this.modelSizeBytes,
    required this.vectorStoreSizeBytes,
    required this.peakRssIndexingBytes,
    required this.peakRssSearchBytes,
    required this.perQuery,
  });

  Map<String, dynamic> toJson() => {
    'datasetName': datasetName,
    'imageCount': imageCount,
    'queryCount': queryCount,
    'timestamp': timestamp.toIso8601String(),
    'quality': {
      'meanRecallAt1': meanRecallAt1,
      'meanRecallAt5': meanRecallAt5,
      'meanRecallAt10': meanRecallAt10,
      'mrr': mrr,
    },
    'latencyMs': {
      'totalIndexing': totalIndexingMs,
      'meanIndexingPerImage': meanIndexingMsPerImage,
      'embeddingLoad': embeddingLoadMs,
      'firstQueryWarmup': firstQueryWarmupMs,
      'totalSearch': totalSearchMs,
      'meanSearchPerQuery': meanSearchMsPerQuery,
      'meanEncodeText': meanEncodeTextMs,
      'meanAnnQuery': meanAnnQueryMs,
    },
    'footprintBytes': {
      'modelSize': modelSizeBytes,
      'vectorStoreSize': vectorStoreSizeBytes,
      'peakRssIndexing': peakRssIndexingBytes,
      'peakRssSearch': peakRssSearchBytes,
    },
    'perQuery': perQuery.map((q) => q.toJson()).toList(),
  };
}
