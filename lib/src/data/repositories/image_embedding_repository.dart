import 'dart:typed_data';

import 'package:mobile_image_search/objectbox.g.dart';
import 'package:mobile_image_search/src/data/interfaces/image_embedding_repository_interface.dart';
import 'package:mobile_image_search/src/data/services/background_worker_service.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_image_embedding.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_repository.dart';

class ImageEmbeddingRepository implements IImageEmbeddingRepository {
  final ObjectBoxService _objectBoxClient;
  late final Box<ObjectBoxImageEmbedding> imageEmbeddingBox;
  late final BackgroundWorkerService _bgWorkerService;

  ImageEmbeddingRepository({
    required ObjectBoxService objectBoxClient,
    required BackgroundWorkerService bgWorkerClient,
  }) : _objectBoxClient = objectBoxClient,
       _bgWorkerService = bgWorkerClient {
    imageEmbeddingBox = _objectBoxClient.store.box<ObjectBoxImageEmbedding>();
  }

  @override
  Future<List<String>> vectorSearch(Float32List queryVector) async {
    final searchQuery = imageEmbeddingBox
        .query(
          ObjectBoxImageEmbedding_.embedding.nearestNeighborsF32(
            queryVector,
            100,
          ),
        )
        .build();
    final searchResults = await searchQuery.findWithScoresAsync();

    return searchResults.map((result) => result.object.assetId).toList();
  }

  @override
  Future<Float32List> generateImageEmbedding(String assetId) async {
    // TODO: implement generateImageEmbedding
    throw UnimplementedError();
  }

  @override
  Future<Float32List> generateTextEmbedding(String text) async {
    return await _bgWorkerService.encodeText(text);
  }
}
