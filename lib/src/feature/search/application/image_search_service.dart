import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_repository.dart';
import 'package:mobile_image_search/src/feature/indexing/domain/store_repository_interface.dart';
import 'package:mobile_image_search/src/feature/search/domain/model/search_result.dart';
import 'package:mobile_image_search/src/feature/indexing/data/background_worker_repo.dart';
import 'package:mobile_image_search/src/shared/domain/interface/background_worker_interface.dart';

class SearchService {
  final IStoreRepository _storeRepo;
  final IBackgroundWorkerRepository _workerRepo;

  SearchService({
    required IStoreRepository storeRepository,
    required IBackgroundWorkerRepository workerRepository,
  }) : _storeRepo = storeRepository,
       _workerRepo = workerRepository;

  Future<List<SearchResultMatch>> searchByCaption(String query) async {
    final Float32List textEmbedding = await _workerRepo.encodeText(query);

    final searchResults = await _storeRepo.semanticSearch(textEmbedding, 200);

    return searchResults;
  }
}

final imageSearchServiceProvider = FutureProvider((ref) async {
  final storeRepository = await ref.watch(objectBoxStoreRepoProvider.future);
  final workerRepository = await ref.watch(backgroundWorkerRepoProvider.future);

  return SearchService(
    storeRepository: storeRepository,
    workerRepository: workerRepository,
  );
});
