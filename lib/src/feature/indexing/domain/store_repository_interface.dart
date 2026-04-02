import 'dart:typed_data';

import 'package:mobile_image_search/src/shared/domain/model/media.dart';
import 'package:mobile_image_search/src/shared/domain/model/search_model.dart';

abstract class IStoreRepository {
  Future<Float32List> getImageEmbedding(String assetId);
  Future<void> saveImageEmbedding(Media media, Float32List embedding);
  void deleteImageEmbeddings(List<String> assetId);
  Future<Map<String, Media>> getAllIndexedMediaMetadata();
  Future<List<SearchResult>> semanticSearch(
    Float32List queryEmbedding,
    int topK,
  );
}
