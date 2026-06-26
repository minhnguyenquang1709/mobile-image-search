import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:mobile_image_search/objectbox.g.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Service abstracting the interaction with ObjectBox database
class ObjectBoxService {
  late final Store store;
  Admin? admin;

  static final ObjectBoxService instance = ObjectBoxService._();

  ObjectBoxService._();

  Future<void> init({ByteData? storeReference}) async {
    final docsDir = await getApplicationSupportDirectory();

    // If a store reference is provided use it to initialize the store instance
    // Otherwise, initialize the store normally
    if (storeReference != null) {
      store = Store.fromReference(getObjectBoxModel(), storeReference);
    } else {
      store = await openStore(
        directory: p.join(docsDir.path, 'image-embedding'),
      );
    }

    final storeDir = Directory(store.directoryPath);
    final dbFile = File('${storeDir.path}/data.mdb');
    debugPrint(
      "[ObjectBoxClient] Current storage size in bytes: ${await dbFile.length()}",
    );

    debugPrint(
      "[ObjectBoxStoreDataSource] Store initialized at ${store.directoryPath}",
    );
    debugPrint(
      "[ObjectBoxStoreDataSource] ObjectBox Admin available: ${Admin.isAvailable()}",
    );

    if (Admin.isAvailable()) {
      admin = Admin(store);
    }
  }

  Future<void> printDbSize() async {
    final storeDir = Directory(store.directoryPath);
    final dbFile = File('${storeDir.path}/data.mdb');
    debugPrint(
      "[ObjectBoxClient] Current storage size in bytes: ${await dbFile.length()}",
    );
  }
}
