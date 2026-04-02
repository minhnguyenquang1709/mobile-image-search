import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_repository.dart';
import 'package:mobile_image_search/src/feature/indexing/domain/store_repository_interface.dart';
import 'package:mobile_image_search/src/shared/application/inference_worker_repository.dart';
import 'package:mobile_image_search/src/shared/domain/interface/background_worker_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/search_model.dart';

class ImageSearchService {
  final IStoreRepository _storeRepo;
  final IInferenceWorkerRepository _workerRepo;

  ImageSearchService({
    required IStoreRepository storeRepository,
    required IInferenceWorkerRepository workerRepository,
  }) : _storeRepo = storeRepository,
       _workerRepo = workerRepository;

  Future<List<SearchResult>> searchByCaption(String query) async {
    final textEncodeResult = await _workerRepo.encodeText(query);
    if (textEncodeResult.errorMessage != null) {
      throw Exception('Text encoding failed: ${textEncodeResult.errorMessage}');
    }

    final embedding = textEncodeResult.embedding;
    final searchResults = await _storeRepo.semanticSearch(embedding, 200);

    return searchResults;
  }
}

final imageSearchServiceProvider = FutureProvider((ref) async {
  final storeRepository = await ref.watch(objectBoxStoreRepoProvider.future);
  final workerRepository = await ref.watch(
    aiInferenceWorkerRepoProvider.future,
  );

  return ImageSearchService(
    storeRepository: storeRepository,
    workerRepository: workerRepository,
  );
});
