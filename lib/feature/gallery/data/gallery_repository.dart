import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:mobile_image_search/core/constants/common.constant.dart';
import 'package:mobile_image_search/core/utils/logger.dart';
import 'package:mobile_image_search/feature/gallery/data/gallery_data_source.dart';
import 'package:mobile_image_search/feature/gallery/domain/interface.dart';
import 'package:mobile_image_search/shared/domain/image_model.dart';

class GalleryRepository implements IGalleryRepository {
  final GalleryDataSource _galleryDataSource;

  GalleryRepository(this._galleryDataSource);

  // bool _hasPermission = false;
  // get hasPermission => _hasPermission;

  // EGallerySyncStatus _syncStatus = EGallerySyncStatus.idle;

  final Logger _logger = loggers[LoggerName.galleryRepository]!;

  bool isGallerySynced = false;

  /// read gallery albums and cache them in memory and record the number of image files
  ///
  /// return domain model
  @override
  Future<List<Image>> readGallery({required int page, int limit = 50}) async {
    final sourceImages = await _galleryDataSource.getAllImages();

    return sourceImages
        .map((asset) => Image(id: asset.id, createdAt: asset.createDateSecond))
        .toList();
  }

  @override
  Future<bool> requestGalleryAccess() async {
    return await _galleryDataSource.requestGalleryAccess();
  }

  @override
  Future<bool> deleteImage(String imageId) async {
    try {
      final result = await _galleryDataSource.deleteImages([imageId]);
      if (result) {
        _logger.printLog('Deleted image with id $imageId from gallery');
      } else {
        _logger.printLog(
          'Failed to delete image with id $imageId from gallery',
        );
      }
      return result;
    } catch (e) {
      _logger.printLog('Error deleting image with id $imageId: $e');
      return false;
    }
  }

  @override
  Future<File> getImageFile(String assetId) async {
    final file = await _galleryDataSource.getImageFile(assetId);
    _logger.printLog('Retrieved file for assetId $assetId');

    if (file == null) {
      _logger.printLog('File for assetId $assetId is null');
      throw FileSystemException('File not found for assetId $assetId');
    }

    return file;
  }
}

final galleryRepository = GalleryRepository(GalleryDataSource());

final galleryRepositoryProvider = Provider((ref) {
  final dataSource = ref.watch(galleryDataSourceProvider);
  return GalleryRepository(dataSource);
});
