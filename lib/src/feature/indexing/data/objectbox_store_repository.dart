import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_data_source.dart';
import 'package:mobile_image_search/src/feature/indexing/data/image_objectbox_model.dart';
import 'package:mobile_image_search/src/shared/domain/model/media.dart';
import 'package:mobile_image_search/src/feature/indexing/domain/store_repository_interface.dart';

class ObjectBoxStoreRepository implements IStoreRepository {
  final ObjectBoxStoreDataSource _dataSource;

  ObjectBoxStoreRepository(this._dataSource);

  @override
  Future<Float32List> getImageEmbedding(String assetId) {
    // TODO: implement getImageEmbedding
    throw UnimplementedError();
  }

  @override
  void saveImageEmbedding(Media media, Float32List embedding) {
    _dataSource.saveImageEmbedding(media, embedding);
  }
}

final objectBoxStoreRepoProvider = FutureProvider((ref) async {
  final dataSource = await ref.watch(objectBoxStoreDataSourceProvider.future);
  return ObjectBoxStoreRepository(dataSource);
});
