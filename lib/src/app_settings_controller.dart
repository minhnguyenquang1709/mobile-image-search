import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/feature/indexing/application/indexing_service.dart';

class AppSettings {
  // indexing state
  final int totalToProcess;
  final int processedCount;

  // similarity threshold
  final double searchSimilarityThreshold;
  final double autoCategorizationThreshold;

  // language
  final String language;

  AppSettings({
    this.totalToProcess = 0,
    this.processedCount = 0,
    this.searchSimilarityThreshold = 0.35,
    this.autoCategorizationThreshold = 0.35,
    this.language = "en",
  });

  AppSettings copyWith({
    int? totalToProcess,
    int? processedCount,
    double? searchSimilarityThreshold,
    double? autoCategorizationThreshold,
    String? language,
  }) {
    return AppSettings(
      totalToProcess: totalToProcess ?? this.totalToProcess,
      processedCount: processedCount ?? this.processedCount,
      searchSimilarityThreshold:
          searchSimilarityThreshold ?? this.searchSimilarityThreshold,
      autoCategorizationThreshold:
          autoCategorizationThreshold ?? this.autoCategorizationThreshold,
      language: language ?? this.language,
    );
  }
}

class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  StreamSubscription<IndexingProgress>? _progressSubscription;

  @override
  FutureOr<AppSettings> build() async {
    final indexingService = await ref.watch(indexingServiceProvider.future);

    // cleanup on dispose
    ref.onDispose(() {
      _progressSubscription?.cancel();
    });

    // listen to progress updates, use stream
    _progressSubscription = indexingService.progressStream.listen((progress) {
      state = AsyncData(
        state.requireValue.copyWith(
          totalToProcess: progress.total,
          processedCount: progress.processed,
        ),
      );
    });

    return AppSettings();
  }

  void updateSearchSimilarityThreshold(double threshold) {
    state = AsyncData(
      state.requireValue.copyWith(searchSimilarityThreshold: threshold),
    );
  }

  void updateAutoCategorizationThreshold(double threshold) {
    state = AsyncData(
      state.requireValue.copyWith(autoCategorizationThreshold: threshold),
    );
  }

  void updateLanguage(String language) {
    state = AsyncData(state.requireValue.copyWith(language: language));
  }
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(
      AppSettingsNotifier.new,
    );
