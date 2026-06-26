import 'dart:typed_data';

abstract class IImageEmbeddingRepository {
  Future<List<String>> vectorSearch(Float32List queryVector);
  Future<Float32List> generateImageEmbedding(String assetId);
  Future<Float32List> generateTextEmbedding(String text);
}
