import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:mobile_image_search/src/data/services/background_worker_service.dart';
import 'package:mobile_image_search/src/shared/domain/model/indexing_progress.dart';

/// Contains business rules related to indexing in background.
///
/// The whole indexing pipeline (device read, diffing, encoding, DB writes) runs
/// inside the worker isolate. This service just kicks it off and relays the
/// progress the worker reports back, so the UI isolate stays free.
///
/// TODO: simplify to only BackgroundWorkerService
class IndexingService {
  final BackgroundWorkerService _workerIsolateClient;

  IndexingProgress _currentIndexingProgress = IndexingProgress(
    total: 0,
    processed: 0,
    isIndexing: false,
  );

  final StreamController<IndexingProgress> _indexingProgressStreamController =
      StreamController.broadcast();

  Stream<IndexingProgress> get progressStream =>
      _indexingProgressStreamController.stream;

  IndexingProgress get currentProgress => _currentIndexingProgress;

  IndexingService({required BackgroundWorkerService workerIsolateClient})
    : _workerIsolateClient = workerIsolateClient;

  bool get isIndexing => _currentIndexingProgress.isIndexing;

  Future<void> init() async {
    // Relay progress reported by the worker isolate.
    _workerIsolateClient.progressStream.listen((progress) {
      _currentIndexingProgress = progress;
      _indexingProgressStreamController.add(progress);
    });
  }

  /// Start the indexing process for all gallery media assets.
  ///
  /// Just triggers the worker isolate to start indexing. The progress is reported via [progressStream].
  Future<void> indexGallery() async {
    if (isIndexing) {
      debugPrint(
        "[IndexingService] Indexing is already in progress, skipping new indexing request",
      );
      return;
    }
    debugPrint("[IndexingService] Requesting background gallery indexing...");
    _currentIndexingProgress = _currentIndexingProgress.copyWith(
      isIndexing: true,
    );
    _indexingProgressStreamController.add(_currentIndexingProgress);

    _workerIsolateClient.startIndexing();
  }
}
