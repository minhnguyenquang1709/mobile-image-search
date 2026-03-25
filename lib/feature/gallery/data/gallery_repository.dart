import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:mobile_image_search/core/constants/common.constant.dart';
import 'package:mobile_image_search/core/utils/logger.dart';
import 'package:mobile_image_search/feature/gallery/data/gallery_data_source.dart';
import 'package:mobile_image_search/feature/gallery/domain/gallery_repository_interface.dart';
import 'package:mobile_image_search/shared/domain/image_model.dart';
import 'package:mobile_image_search/shared/domain/interface/image_interface.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager/src/types/entity.dart';

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
    final sourceImages = await _galleryDataSource.getImages(
      page: page,
      limit: limit,
    );

    final List<Image> assets = [];

    for (final asset in sourceImages) {
      if (asset.type == AssetType.image || asset.type == AssetType.video) {
        final IImageMetadata metadata = IImageMetadata(
          name: asset.title!,
          createDateTime: asset.createDateTime,
          modifiedDateTime: asset.modifiedDateTime,
        );
        assets.add(Image(assetEntity: asset, metadata: metadata));
      }
    }

    return assets;

    // return sourceImages.map((asset) {
    //   if (asset.type != AssetType.image && asset.type != AssetType.video) {}
    //   final IImageMetadata metadata = IImageMetadata(
    //     name: asset.title!,
    //     createDateTime: asset.createDateTime,
    //     modifiedDateTime: asset.modifiedDateTime,
    //   );
    //   return Image(assetEntity: asset, metadata: metadata);
    // }).toList();
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

  @override
  Future<void> getImageMetadata(String assetId) {
    return _galleryDataSource.getImageMetadata(assetId);
  }

  @override
  Future<List<IImageMetadata>> getAllMetadata() async {
    final List<AssetEntity> allImageAssets = await _galleryDataSource
        .getAllImages();
    return allImageAssets.map((asset) {
      return IImageMetadata(
        name: asset.title!,
        createDateTime: asset.createDateTime,
        modifiedDateTime: asset.modifiedDateTime,
      );
    }).toList();
  }

  @override
  Future<List<AssetPathEntity>> getAlbumList() async {
    final List<AssetPathEntity> albumLists = await _galleryDataSource
        .getAllAlbums();
    return albumLists;
  }

  @override
  Future<List<Image>> readAlbum({
    required String albumId,
    required int page,
    int limit = 50,
  }) async {
    final List<AssetEntity> albumImageAssets = await _galleryDataSource
        .getImagesFromAlbum(albumId: albumId, page: page, limit: limit);

    return albumImageAssets.map((asset) {
      final IImageMetadata metadata = IImageMetadata(
        name: asset.title!,
        createDateTime: asset.createDateTime,
        modifiedDateTime: asset.modifiedDateTime,
      );
      return Image(assetEntity: asset, metadata: metadata);
    }).toList();
  }

  @override
  Future<void> createAlbum(String albumName) async {
    await _galleryDataSource.createAlbum(albumName);
  }

  @override
  Future<void> moveImagesToAlbum(
    List<String> assetIds,
    String targetAlbumId,
  ) async {
    // TODO: implement moveImagesToAlbum
    throw UnimplementedError();
  }

  @override
  Future<void> deleteAlbum(String albumId) async {
    // TODO: implement deleteAlbum
    throw UnimplementedError();
  }
}

final galleryRepository = GalleryRepository(GalleryDataSource());

final galleryRepositoryProvider = Provider((ref) {
  final dataSource = ref.watch(galleryDataSourceProvider);
  return GalleryRepository(dataSource);
});
