import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mobile_image_search/objectbox.g.dart';
import 'package:mobile_image_search/src/data/services/background_worker_service.dart';
import 'package:mobile_image_search/src/feature/evaluation/domain/eval_metrics.dart'
    as metrics;
import 'package:mobile_image_search/src/feature/evaluation/domain/eval_progress.dart';
import 'package:mobile_image_search/src/feature/evaluation/domain/evaluation_report.dart';
import 'package:mobile_image_search/src/feature/evaluation/domain/ground_truth.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_image_embedding.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class _RssSampler {
  int peak = 0;
  Timer? _timer;

  void start() {
    _sample();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) => _sample());
  }

  void _sample() {
    final int rss = ProcessInfo.currentRss;
    if (rss > peak) peak = rss;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

/// evaluate the CLIP retrieval model on a labelled dataset
class EvaluationService {
  final BackgroundWorkerService _workerService;
  final String _textEncoderPath;
  final String _imageEncoderPath;
  final String _vocabPath;
  final String _mergesPath;

  EvaluationService({
    required BackgroundWorkerService workerService,
    required String textEncoderPath,
    required String imageEncoderPath,
    required String vocabPath,
    required String mergesPath,
  }) : _workerService = workerService,
       _textEncoderPath = textEncoderPath,
       _imageEncoderPath = imageEncoderPath,
       _vocabPath = vocabPath,
       _mergesPath = mergesPath;

  /// filesystem path of the most recently exported report
  String? lastReportPath;

  static const List<String> _imageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
  ];

  Future<EvaluationReport> run(
    String datasetDir, {
    void Function(EvalProgress)? onProgress,
  }) async {
    void report(EvalProgress progress) => onProgress?.call(progress);

    report(const EvalProgress(phase: EvalPhase.loading));

    final PermissionStatus status = await Permission.manageExternalStorage
        .request();
    if (!status.isGranted) {
      throw Exception(
        'Storage permission denied. Grant "All files access" to this app in '
        'Settings to read the dataset folder.',
      );
    }

    final GroundTruth groundTruth = GroundTruth.fromCsvFile(
      p.join(datasetDir, 'ground_truth.csv'),
    );
    final List<File> imageFiles = _listImageFiles(datasetDir);
    if (imageFiles.isEmpty) {
      throw Exception("No images found in dataset folder: $datasetDir");
    }

    _warnMissingLabels(groundTruth, imageFiles);

    final Directory supportDir = await getApplicationSupportDirectory();
    final String evalStorePath = p.join(supportDir.path, 'eval_store');
    final Directory evalStoreDir = Directory(evalStorePath);
    if (evalStoreDir.existsSync()) {
      evalStoreDir.deleteSync(recursive: true);
    }

    Store store = await openStore(directory: evalStorePath);
    try {
      report(
        EvalProgress(
          phase: EvalPhase.indexing,
          current: 0,
          total: imageFiles.length,
        ),
      );
      final _RssSampler indexingRss = _RssSampler()..start();
      final Stopwatch indexingWatch = Stopwatch()..start();

      final Box<ObjectBoxImageEmbedding> box = store
          .box<ObjectBoxImageEmbedding>();
      for (int i = 0; i < imageFiles.length; i++) {
        final File file = imageFiles[i];
        final String basename = p.basename(file.path);
        try {
          final Uint8List bytes = await file.readAsBytes();
          final Float32List embedding = await _workerService.encodeImage(
            basename,
            basename,
            bytes,
          );
          await box.putAsync(
            ObjectBoxImageEmbedding(
              assetId: basename,
              title: basename,
              mediaType: 0,
              embedding: embedding.toList(),
              mediaCreatedAt: DateTime.now(),
              mediaModifiedAt: DateTime.now(),
            ),
          );
        } catch (e) {
          debugPrint("[EvaluationService] Failed to index $basename: $e");
        }
        report(
          EvalProgress(
            phase: EvalPhase.indexing,
            current: i + 1,
            total: imageFiles.length,
          ),
        );
      }

      indexingWatch.stop();
      indexingRss.stop();
      final int totalIndexingMs = indexingWatch.elapsedMilliseconds;

      report(const EvalProgress(phase: EvalPhase.loadingEmbeddings));
      store.close();
      store = await openStore(directory: evalStorePath);
      final Box<ObjectBoxImageEmbedding> reopenedBox = store
          .box<ObjectBoxImageEmbedding>();
      final Stopwatch loadWatch = Stopwatch()..start();
      final List<ObjectBoxImageEmbedding> allEmbeddings = await reopenedBox
          .getAllAsync();
      loadWatch.stop();
      final int embeddingLoadMs = loadWatch.elapsedMilliseconds;
      final int indexedCount = allEmbeddings.length;

      final List<String> queries = groundTruth.queries;
      report(
        EvalProgress(
          phase: EvalPhase.searching,
          current: 0,
          total: queries.length,
        ),
      );
      final _RssSampler searchRss = _RssSampler()..start();

      final List<QueryEvalResult> perQueryResult = [];
      int totalSearchMs = 0;
      int totalEncodeTextMs = 0;
      int totalAnnMs = 0;
      int firstQueryWarmupMs = 0;

      for (int i = 0; i < queries.length; i++) {
        final String query = queries[i];
        final Set<String> relevant = groundTruth.relevantFor(query).toSet();

        final Stopwatch encodeWatch = Stopwatch()..start();
        final Float32List queryVector = await _workerService.encodeText(query);
        encodeWatch.stop();

        final Stopwatch annWatch = Stopwatch()..start();
        final Query<ObjectBoxImageEmbedding> annQuery = reopenedBox
            .query(
              ObjectBoxImageEmbedding_.embedding.nearestNeighborsF32(
                queryVector,
                indexedCount,
              ),
            )
            .build();
        final results = await annQuery.findWithScoresAsync();
        annQuery.close();
        annWatch.stop();

        results.sort((a, b) => a.score.compareTo(b.score));
        final List<String> ranked = results
            .map((r) => r.object.assetId)
            .toList();

        if (i == 0) firstQueryWarmupMs = annWatch.elapsedMilliseconds;
        totalEncodeTextMs += encodeWatch.elapsedMilliseconds;
        totalAnnMs += annWatch.elapsedMilliseconds;
        totalSearchMs +=
            encodeWatch.elapsedMilliseconds + annWatch.elapsedMilliseconds;

        perQueryResult.add(
          QueryEvalResult(
            query: query,
            rankedTop10: ranked.take(10).toList(),
            r1: metrics.recallAtK(ranked, relevant, 1),
            r5: metrics.recallAtK(ranked, relevant, 5),
            r10: metrics.recallAtK(ranked, relevant, 10),
            rr: metrics.reciprocalRank(ranked, relevant),
            firstHitRank: metrics.firstHitRank(ranked, relevant),
          ),
        );

        report(
          EvalProgress(
            phase: EvalPhase.searching,
            current: i + 1,
            total: queries.length,
          ),
        );
      }

      searchRss.stop();

      final int modelSizeBytes = _modelSizeBytes();
      final int vectorStoreSizeBytes = _storeSizeBytes(store.directoryPath);

      final EvaluationReport evaluationReport = _aggregate(
        datasetDir: datasetDir,
        imageCount: imageFiles.length,
        perQuery: perQueryResult,
        totalIndexingMs: totalIndexingMs,
        embeddingLoadMs: embeddingLoadMs,
        firstQueryWarmupMs: firstQueryWarmupMs,
        totalSearchMs: totalSearchMs,
        totalEncodeTextMs: totalEncodeTextMs,
        totalAnnMs: totalAnnMs,
        modelSizeBytes: modelSizeBytes,
        vectorStoreSizeBytes: vectorStoreSizeBytes,
        peakRssIndexingBytes: indexingRss.peak,
        peakRssSearchBytes: searchRss.peak,
      );

      await _exportReport(evaluationReport);
      report(const EvalProgress(phase: EvalPhase.done));
      return evaluationReport;
    } finally {
      // teardown: close + delete the eval store
      store.close();
      if (evalStoreDir.existsSync()) {
        evalStoreDir.deleteSync(recursive: true);
      }
    }
  }

  List<File> _listImageFiles(String datasetDir) {
    return Directory(datasetDir)
        .listSync()
        .whereType<File>()
        .where(
          (f) => _imageExtensions.contains(p.extension(f.path).toLowerCase()),
        )
        .toList();
  }

  void _warnMissingLabels(GroundTruth groundTruth, List<File> imageFiles) {
    final Set<String> present = imageFiles
        .map((f) => p.basename(f.path).toLowerCase())
        .toSet();
    for (final query in groundTruth.queries) {
      for (final name in groundTruth.relevantFor(query)) {
        if (!present.contains(p.basename(name).toLowerCase())) {
          debugPrint(
            "[EvaluationService] Ground-truth file not in folder: $name (query: '$query')",
          );
        }
      }
    }
  }

  int _modelSizeBytes() {
    int total = 0;
    for (final path in [
      _textEncoderPath,
      _imageEncoderPath,
      _vocabPath,
      _mergesPath,
    ]) {
      final File file = File(path);
      if (file.existsSync()) total += file.lengthSync();
    }
    return total;
  }

  int _storeSizeBytes(String storeDirPath) {
    int total = 0;
    for (final name in ['data.mdb', 'lock.mdb']) {
      final File file = File(p.join(storeDirPath, name));
      if (file.existsSync()) total += file.lengthSync();
    }
    return total;
  }

  EvaluationReport _aggregate({
    required String datasetDir,
    required int imageCount,
    required List<QueryEvalResult> perQuery,
    required int totalIndexingMs,
    required int embeddingLoadMs,
    required int firstQueryWarmupMs,
    required int totalSearchMs,
    required int totalEncodeTextMs,
    required int totalAnnMs,
    required int modelSizeBytes,
    required int vectorStoreSizeBytes,
    required int peakRssIndexingBytes,
    required int peakRssSearchBytes,
  }) {
    final int queryCount = perQuery.length;

    double meanR1 = 0;
    double meanR5 = 0;
    double meanR10 = 0;
    double mrr = 0;
    for (final q in perQuery) {
      meanR1 += q.r1;
      meanR5 += q.r5;
      meanR10 += q.r10;
      mrr += q.rr;
    }
    meanR1 = queryCount == 0 ? 0 : meanR1 / queryCount;
    meanR5 = queryCount == 0 ? 0 : meanR5 / queryCount;
    meanR10 = queryCount == 0 ? 0 : meanR10 / queryCount;
    mrr = queryCount == 0 ? 0 : mrr / queryCount;

    return EvaluationReport(
      datasetName: p.basename(datasetDir),
      imageCount: imageCount,
      queryCount: queryCount,
      timestamp: DateTime.now(),
      meanRecallAt1: meanR1,
      meanRecallAt5: meanR5,
      meanRecallAt10: meanR10,
      mrr: mrr,
      totalIndexingMs: totalIndexingMs,
      meanIndexingMsPerImage: imageCount == 0
          ? 0
          : totalIndexingMs / imageCount,
      embeddingLoadMs: embeddingLoadMs,
      firstQueryWarmupMs: firstQueryWarmupMs,
      totalSearchMs: totalSearchMs,
      meanSearchMsPerQuery: queryCount == 0 ? 0 : totalSearchMs / queryCount,
      meanEncodeTextMs: queryCount == 0 ? 0 : totalEncodeTextMs / queryCount,
      meanAnnQueryMs: queryCount == 0 ? 0 : totalAnnMs / queryCount,
      modelSizeBytes: modelSizeBytes,
      vectorStoreSizeBytes: vectorStoreSizeBytes,
      peakRssIndexingBytes: peakRssIndexingBytes,
      peakRssSearchBytes: peakRssSearchBytes,
      perQuery: perQuery,
    );
  }

  Future<String> _exportReport(EvaluationReport report) async {
    Directory? baseDir = await getExternalStorageDirectory();
    baseDir ??= await getApplicationSupportDirectory();

    final Directory reportsDir = Directory(
      p.join(baseDir.path, 'eval_reports'),
    );
    if (!reportsDir.existsSync()) {
      reportsDir.createSync(recursive: true);
    }

    final String fileName =
        'eval_${report.timestamp.millisecondsSinceEpoch}.json';
    final File outFile = File(p.join(reportsDir.path, fileName));
    await outFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report.toJson()),
    );
    debugPrint("[EvaluationService] Report written to ${outFile.path}");
    lastReportPath = outFile.path;
    return outFile.path;
  }
}
