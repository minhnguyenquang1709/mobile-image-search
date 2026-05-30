import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/objectbox.g.dart';
import 'package:mobile_image_search/src/constants/common_constant.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_data_source.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_image_embedding.dart';
import 'package:mobile_image_search/src/feature/search/domain/model/search_result.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:mobile_image_search/src/feature/indexing/domain/store_repository_interface.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Data source abstracting the interaction with ObjectBox database
class ObjectBoxClient {
  late final Store store;
  Admin? admin;

  static final ObjectBoxClient instance = ObjectBoxClient._();

  ObjectBoxClient._();

  Future<void> init() async {
    final docsDir = await getApplicationSupportDirectory();
    store = await openStore(directory: p.join(docsDir.path, 'image-embedding'));

    // TODO: remove debug print
    print(
      "[ObjectBoxStoreDataSource] Store initialized at ${store.directoryPath}",
    );
    print(
      "[ObjectBoxStoreDataSource] ObjectBox Admin available: ${Admin.isAvailable()}",
    );

    if (Admin.isAvailable()) {
      admin = Admin(store);
    }
  }
}

final objectBoxClientProvider = FutureProvider<ObjectBoxClient>((ref) async {
  final client = ObjectBoxClient.instance;
  await client.init();
  return client;
});

class ObjectBoxStoreRepository implements IStoreRepository {
  final ObjectBoxClient _objectBoxClient;

  ObjectBoxStoreRepository(this._objectBoxClient);

  // @override
  // Future<Float32List> getImageEmbedding(String assetId) async {
  //   final imageEmbeddingBox = _dataSource.store.box<ImageObjectBox>();
  //   final query = imageEmbeddingBox
  //       .query(ImageObjectBox_.assetId.equals(assetId))
  //       .build();
  //   final result = query.findFirst();
  //   query.close();

  //   if (result == null) {
  //     throw Exception("No embedding found for assetId: $assetId");
  //   }

  //   return Float32List.fromList(result.embedding);
  // }

  @override
  Future<bool> saveImageEmbedding(
    MediaAsset mediaAsset,
    Float32List embedding,
  ) async {
    try {
      final imageEmbeddingBox = _objectBoxClient.store
          .box<ObjectBoxImageEmbedding>();
      final ObjectBoxImageEmbedding newImageEmbedding = ObjectBoxImageEmbedding(
        assetId: mediaAsset.assetId,
        title: mediaAsset.title,
        mediaType: mediaAsset.mediaType == EMediaType.video ? 1 : 0,
        embedding: embedding,
        mediaCreatedAt: mediaAsset.createDateTime,
        mediaModifiedAt: mediaAsset.modifiedDateTime,
      );
      await imageEmbeddingBox.putAsync(newImageEmbedding);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> deleteImageEmbeddings(List<String> assetIds) async {
    try {
      final imageEmbeddingBox = _objectBoxClient.store
          .box<ObjectBoxImageEmbedding>();
      for (final id in assetIds) {
        final query = imageEmbeddingBox
            .query(ImageObjectBox_.assetId.equals(id))
            .build();
        query.remove();
      }
      return true;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, MediaAsset>> getAllIndexedImageMetadata() async {
    throw UnimplementedError();
    // final imageBox = _dataSource.store.box<ImageObjectBox>();
    // final allIndexedImages = imageBox.getAll();

    // final Map<String, MediaAsset> metadataMap = {};
    // for (final image in allIndexedImages) {
    //   final media = MediaAsset(
    //     assetId: image.assetId,
    //     title: "",
    //     mediaType: EMediaType.image,
    //     createDateTime: image.createdAt,
    //     modifiedDateTime: image.modifiedAt,
    //     width: null,
    //     height: null,
    //     format: null,
    //   );
    //   metadataMap[image.assetId] = media;
    // }
    // return metadataMap;
  }

  @override
  Future<List<SearchResultMatch>> semanticSearch(
    Float32List queryEmbedding,
    int topK,
  ) async {
    throw UnimplementedError();
    // List<SearchResultMatch> searchResults = [];
    // final query = _dataSource.store
    //     .box<ImageObjectBox>()
    //     .query(
    //       ImageObjectBox_.embedding.nearestNeighborsF32(queryEmbedding, topK),
    //     )
    //     .build();

    // final results = await query.findWithScoresAsync();

    // for (final result in results) {
    //   searchResults.add(
    //     SearchResultMatch(
    //       mediaAsset: result.object.toImageAsset(),
    //       cosineScore: result.score,
    //     ),
    //   );
    // }

    // return searchResults;
  }
}

final objectBoxStoreRepoProvider = FutureProvider((ref) async {
  final objectBoxClient = await ref.watch(objectBoxClientProvider.future);
  return ObjectBoxStoreRepository(objectBoxClient);
});
