import 'package:objectbox/objectbox.dart';
import 'package:mobile_image_search/objectbox.g.dart';

class StoreService {
  static final StoreService _instance = StoreService._internal();

  late final ObjectBox _objectBox;

  factory StoreService() {
    return _instance;
  }

  StoreService._internal();

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
