import 'dart:typed_data';

import 'package:mobile_image_search/src/shared/domain/model/media.dart';

abstract class IStoreRepository {
  Future<Float32List> getImageEmbedding(String assetId);
  void saveImageEmbedding(Media media, Float32List embedding);
  void deleteImageEmbeddings(List<String> assetId);
  Future<Map<String, Media>> getAllIndexedMediaMetadata();
}
