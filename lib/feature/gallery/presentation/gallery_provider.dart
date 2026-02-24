import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/feature/gallery/data/gallery_repository.dart';
import 'package:photo_manager/photo_manager.dart';

/// notifier
class GalleryNotifier extends AsyncNotifier<List<AssetEntity>> {
  /// initialize the gallery repository and sync the gallery
  @override
  Future<List<AssetEntity>> build() async {
    final galleryRepo = ref.watch(galleryRepositoryProvider);
    return galleryRepo.assets;
  }
}

/// provider
final galleryProvider =
    AsyncNotifierProvider<GalleryNotifier, List<AssetEntity>>(() {
      return GalleryNotifier();
    });
