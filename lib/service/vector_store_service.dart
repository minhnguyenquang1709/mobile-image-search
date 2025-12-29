import 'package:objectbox/objectbox.dart';
import 'package:mobile_image_search/objectbox.g.dart';

class VectorStoreService {
  static final VectorStoreService _instance = VectorStoreService._internal();

  late final ObjectBox _objectBox;

  factory VectorStoreService() {
    return _instance;
  }

  VectorStoreService._internal();

  Future<void> init() async {
    _objectBox = await ObjectBox.create();
  }
}

class ObjectBox {
  late final Store store;
  ObjectBox._create(this.store);

  static Future<ObjectBox> create() async {
    final store = await openStore();
    return ObjectBox._create(store);
  }
}
