import 'dart:typed_data';

import 'package:mobile_image_search/shared/domain/media.dart';

abstract class IStoreRepository {
  Future<Float32List> getImageEmbedding(String assetId);
  void saveImageEmbedding(Media media, Float32List embedding);
}
