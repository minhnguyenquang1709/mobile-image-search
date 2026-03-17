import 'dart:typed_data';

abstract class IStoreRepository {
  Future<Float32List> getImageEmbedding(String assetId);
  void saveImageEmbedding(String assetId, Float32List embedding);
}
