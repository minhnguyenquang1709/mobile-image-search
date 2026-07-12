import 'dart:typed_data';

abstract class IImageEmbeddingRepository {
  Future<List<String>> vectorSearch(Float32List queryVector, {int limit = 100});
  Future<Float32List> generateImageEmbedding(String assetId);
  Future<Float32List> generateTextEmbedding(String text);
  Future<void> deleteImageEmbeddings(List<String> assetIds);

  // emits the deleted asset ids to update UI
  Stream<List<String>> get embeddingsDeleted;
}
