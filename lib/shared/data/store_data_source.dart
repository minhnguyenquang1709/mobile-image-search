import 'package:mobile_image_search/objectbox.g.dart';

/// ObjectBox wrapper
///
/// - handle store init
///
/// - provide store instance
class StoreDataSource {
  late final Store store;

  StoreDataSource();

  Future<void> init() async {
    store = await openStore(directory: 'image-embedding');

    if (Admin.isAvailable()) {
      Admin admin = Admin(store);
    }
  }
}
