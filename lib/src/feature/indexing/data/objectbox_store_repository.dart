import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/objectbox.g.dart';
import 'package:mobile_image_search/src/constants/common_constant.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_data_source.dart';
import 'package:mobile_image_search/src/feature/indexing/data/image_objectbox_model.dart';
import 'package:mobile_image_search/src/shared/domain/model/media.dart';
import 'package:mobile_image_search/src/feature/indexing/domain/store_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/search_model.dart';

class ObjectBoxStoreRepository implements IStoreRepository {
  final ObjectBoxStoreDataSource _dataSource;

  ObjectBoxStoreRepository(this._dataSource);

  @override
  Future<Float32List> getImageEmbedding(String assetId) async {
    final imageEmbeddingBox = _dataSource.store.box<ImageObjectBox>();
    final query = imageEmbeddingBox
        .query(ImageObjectBox_.assetId.equals(assetId))
        .build();
    final result = query.findFirst();
    query.close();

    if (result == null) {
      throw Exception("No embedding found for assetId: $assetId");
    }

    return Float32List.fromList(result.embedding);
  }

  @override
  Future<void> saveImageEmbedding(Media media, Float32List embedding) async {
    await _dataSource.saveImageEmbedding(media, embedding);
  }

  @override
  void deleteImageEmbeddings(List<String> assetId) {
    final imageEmbeddingBox = _dataSource.store.box<ImageObjectBox>();
    for (final id in assetId) {
      final query = imageEmbeddingBox
          .query(ImageObjectBox_.assetId.equals(id))
          .build();
      query.remove();
    }
    return;
  }

  @override
  Future<Map<String, Media>> getAllIndexedMediaMetadata() async {
    final imageBox = _dataSource.store.box<ImageObjectBox>();
    final allIndexedImages = imageBox.getAll();

    final Map<String, Media> metadataMap = {};
    for (final image in allIndexedImages) {
      final media = Media(
        assetId: image.assetId,
        name: "",
        mediaType: EMediaType.image,
        createDateTime: image.createdAt,
        modifiedDateTime: image.modifiedAt,
      );
      metadataMap[image.assetId] = media;
    }
    return metadataMap;
  }

  @override
  Future<List<SearchResult>> semanticSearch(
    Float32List queryEmbedding,
    int topK,
  ) async {
    List<SearchResult> searchResults = [];
    final query = _dataSource.store
        .box<ImageObjectBox>()
        .query(
          ImageObjectBox_.embedding.nearestNeighborsF32(queryEmbedding, topK),
        )
        .build();

    final results = await query.findWithScoresAsync();

    for (final result in results) {
      searchResults.add(
        SearchResult(assetId: result.object.assetId, similarity: result.score),
      );
    }

    return searchResults;
  }
}

final objectBoxStoreRepoProvider = FutureProvider((ref) async {
  final dataSource = await ref.watch(objectBoxStoreDataSourceProvider.future);
  return ObjectBoxStoreRepository(dataSource);
});
