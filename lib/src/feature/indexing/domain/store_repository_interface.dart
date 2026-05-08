import 'dart:typed_data';

import 'package:mobile_image_search/src/feature/search/domain/model/search_result.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

abstract class IStoreRepository {
  Future<bool> saveImageEmbedding(MediaAsset mediaAsset, Float32List embedding);
  Future<bool> deleteImageEmbeddings(List<String> assetIds);
  Future<List<SearchResultMatch>> semanticSearch(
    Float32List queryEmbedding,
    int topK,
  );
  Future<Map<String, MediaAsset>> getAllIndexedImageMetadata();
}
