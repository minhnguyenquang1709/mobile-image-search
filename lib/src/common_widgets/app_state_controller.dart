import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppState {
  // indexing state
  int totalToProcess = 0;
  int processedCount = 0;

  // similarity threshold
  double searchSimilarityThreshold = 0.4;
  double autoCategorizationThreshold = 0.4;

  AppState();
}

class AppStateController extends StateNotifier<AppState> {
  AppStateController() : super(AppState());

  @override
  AppState build() {
    return AppState();
  }
}
