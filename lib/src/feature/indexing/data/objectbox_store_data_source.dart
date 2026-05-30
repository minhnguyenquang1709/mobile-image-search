import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/objectbox.g.dart';
import 'package:mobile_image_search/src/constants/common_constant.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_image_embedding.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// ObjectBox database wrapper
///
/// * handle store init
///
/// * provide store instance
// class ObjectBoxStoreDataSource {
//   late final Store store;
//   Admin? admin;

//   ObjectBoxStoreDataSource();

//   Future<void> init() async {
//     final docsDir = await getApplicationDocumentsDirectory();
//     store = await openStore(directory: p.join(docsDir.path, 'image-embedding'));

//     // TODO: remove debug print
//     print(
//       "[ObjectBoxStoreDataSource] Store initialized at ${store.directoryPath}",
//     );
//     print(
//       "[ObjectBoxStoreDataSource] ObjectBox Admin available: ${Admin.isAvailable()}",
//     );
//     if (Admin.isAvailable()) {
//       admin = Admin(store);
//     }

//     // TODO: remove this debug database cleanup
//     final imageEmbeddingBox = store.box<ImageObjectBox>();
//     imageEmbeddingBox.removeAll();
//   }

//   Future<void> saveImageEmbedding(
//     MediaAsset mediaAsset,
//     Float32List embedding,
//   ) async {
//     final imageBox = store.box<ImageObjectBox>();
//     ImageObjectBox image = ImageObjectBox(
//       assetId: mediaAsset.assetId,
//       title: mediaAsset.title,
//       embedding: embedding,
//       createdAt: mediaAsset.createDateTime,
//       modifiedAt: mediaAsset.modifiedDateTime,
//       mediaType: mediaAsset.mediaType == EMediaType.video ? 1 : 0,
//     );
//     await imageBox.putAsync(image);
//   }
// }

// final objectBoxStoreDataSourceProvider =
//     FutureProvider<ObjectBoxStoreDataSource>((ref) async {
//       final dataSource = ObjectBoxStoreDataSource();
//       await dataSource.init();
//       return dataSource;
//     });
