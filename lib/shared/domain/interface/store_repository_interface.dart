import 'dart:typed_data';

abstract class IStoreRepository {
  Future<Float32List> getImageEmbedding(String assetId);
}
