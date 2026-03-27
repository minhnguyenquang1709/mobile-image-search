import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/shared/data/data_source/objectbox_store_data_source.dart';
import 'package:mobile_image_search/shared/data/model/image_objectbox_model.dart';
import 'package:mobile_image_search/shared/domain/model/media.dart';
import 'package:mobile_image_search/shared/domain/interface/store_repository_interface.dart';

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
