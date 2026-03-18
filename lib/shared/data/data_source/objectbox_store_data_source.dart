import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/objectbox.g.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// ObjectBox database wrapper
///
/// * handle store init
///
/// * provide store instance
class ObjectBoxStoreDataSource {
  late final Store store;
  Admin? admin;

  ObjectBoxStoreDataSource();

  Future<void> init() async {
    final docsDir = await getApplicationDocumentsDirectory();
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

final objectBoxStoreDataSourceProvider =
    FutureProvider<ObjectBoxStoreDataSource>((ref) async {
      final dataSource = ObjectBoxStoreDataSource();
      await dataSource.init();
      return dataSource;
    });
