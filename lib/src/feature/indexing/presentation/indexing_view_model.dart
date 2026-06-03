import 'package:flutter/foundation.dart';
import 'package:mobile_image_search/src/feature/indexing/application/indexing_service.dart';
import 'package:mobile_image_search/src/service_locator.dart';
import 'package:mobile_image_search/src/shared/domain/model/indexing_progress.dart';

/// ViewModel for the "Image Indexing in Background" feature
class IndexingViewModel extends ChangeNotifier {
  static IndexingViewModel? _instance;

  final IndexingService _service;

  IndexingViewModel._internal(this._service);

  factory IndexingViewModel({IndexingService? service}) {
    if (_instance == null) {
      if (service == null) {
        throw Exception(
          "[IndexingViewModel] Service must be provided for the first initialization",
        );
      }
      // 1st initilization
      _instance = IndexingViewModel._internal(service);
      _instance!._service.progressStream.listen((progress) {
        _instance!._currentIndexingProgress = progress;
        _instance!.notifyListeners();
        debugPrint(
          "[IndexingViewModel] Received indexing progress update: ${progress.processed} / ${progress.total}",
        );
      });
    }
    return _instance!;
  }

  static IndexingViewModel get instance {
    if (_instance == null) {
      throw Exception(
        "[IndexingViewModel] Instance not initialized. Call IndexingViewModel(service: yourService) first.",
      );
    }
    return _instance!;
  }

  IndexingProgress _currentIndexingProgress = IndexingProgress(
    total: 0,
    processed: 0,
    isIndexing: false,
  );

  IndexingProgress get currentProgress => _currentIndexingProgress;
}

final IndexingViewModel indexingViewModel = IndexingViewModel(
  service: ServiceLocator.indexingService,
);
