import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/feature/indexing/application/indexing_service.dart';

class AppSettings {
  // service
  final IndexingService indexingService;

  // indexing state
  int totalToProcess = 0;
  int processedCount = 0;

  // similarity threshold
  double searchSimilarityThreshold = 0.4;
  double autoCategorizationThreshold = 0.4;

  AppSettings({required this.indexingService});
}

final appSettingsProvider = FutureProvider((ref) async {
  final indexingService = await ref.watch(indexingServiceProvider.future);
  return AppSettings(indexingService: indexingService);
});
