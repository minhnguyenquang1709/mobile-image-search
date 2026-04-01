import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/constants/common_constant.dart';
// import 'package:mobile_image_search/core/constants/common.constant.dart';
import 'package:mobile_image_search/src/utils/logger.dart';
import 'package:mobile_image_search/src/utils/media_processing.dart';
import 'package:mobile_image_search/src/feature/gallery/data/gallery_data_source.dart';
import 'package:mobile_image_search/src/feature/gallery/domain/gallery_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/media.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_metadata.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryRepository implements IGalleryRepository {
  final GalleryDataSource _galleryDataSource;

  static final Map<String, AssetEntity> _assetCache = {};

  GalleryRepository(this._galleryDataSource);

  // bool _hasPermission = false;
  // get hasPermission => _hasPermission;

  final Logger _logger = loggers[LoggerName.galleryRepository]!;

  bool isGallerySynced = false;

  /// Read gallery albums and cache them in memory and record the number of image files
  ///
  /// Return domain model
  @override
  Future<List<Media>> readGallery({required int page, int limit = 50}) async {
    final List<AssetEntity> sourceImages = await _galleryDataSource.getImages(
      page: page,
      limit: limit,
    );

    final List<Media> assets = [];

    for (final asset in sourceImages) {
      _assetCache[asset.id] = asset;
      if (asset.type == AssetType.image || asset.type == AssetType.video) {
        final MediaMetadata metadata = fillMetadataFromAsset(asset);
        assets.add(Media(assetId: asset.id, metadata: metadata));
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
  Future<MediaMetadata> getImageMetadata(String assetId) {
    return _galleryDataSource.getImageMetadata(assetId);
  }

  @override
  Future<List<MediaMetadata>> getAllMetadata() async {
    final RootIsolateToken? rootIsolateToken = RootIsolateToken.instance;
    final List<AssetEntity> allImageAssets = await Isolate.run(() async {
      if (rootIsolateToken != null) {
        BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
      }
      return await _galleryDataSource.getAllImages();
    });

    _logger.printLog('Fetched all image assets!');

    return allImageAssets.map((asset) {
      return fillMetadataFromAsset(asset);
    }).toList();
  }

  @override
  Future<List<AssetPathEntity>> getAlbumList() async {
    final List<AssetPathEntity> albumLists = await _galleryDataSource
        .getAllAlbums();
    return albumLists;
  }

  @override
  Future<List<Media>> readAlbum({
    required String albumId,
    required int page,
    int limit = 50,
  }) async {
    final List<AssetEntity> albumImageAssets = await _galleryDataSource
        .getImagesFromAlbum(albumId: albumId, page: page, limit: limit);

    return albumImageAssets.map((asset) {
      final MediaMetadata metadata = MediaMetadata(
        name: asset.title!,
        createDateTime: asset.createDateTime,
        modifiedDateTime: asset.modifiedDateTime,
        mediaType: asset.type == AssetType.image
            ? EMediaType.image
            : EMediaType.video,
      );
      return Media(assetId: asset.id, metadata: metadata);
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
