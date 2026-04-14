import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/constants/common_constant.dart';
// import 'package:mobile_image_search/core/constants/common.constant.dart';
import 'package:mobile_image_search/src/utils/media_processing.dart';
import 'package:mobile_image_search/src/feature/gallery/data/gallery_data_source.dart';
import 'package:mobile_image_search/src/shared/domain/interface/gallery_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/media.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_metadata.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryRepository implements IGalleryRepository {
  final GalleryDataSource _galleryDataSource;

  static final Map<String, AssetEntity> _assetCache = {};

  GalleryRepository(this._galleryDataSource);

  // bool _hasPermission = false;
  // get hasPermission => _hasPermission;

  bool isGallerySynced = false;

  /// Read gallery albums and cache them in memory and record the number of image files
  ///
  /// Return domain model
  @override
  Future<List<MediaAsset>> readGallery({
    required int page,
    int limit = 50,
  }) async {
    final List<AssetEntity> sourceImages = await _galleryDataSource.getImages(
      page: page,
      limit: limit,
    );

    final List<MediaAsset> assets = [];

    for (final asset in sourceImages) {
      _assetCache[asset.id] = asset;
      if (asset.type == AssetType.image || asset.type == AssetType.video) {
        final MediaAsset media = fillMetadataFromAsset(asset);
        assets.add(media);
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
      } else {}
      return result;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<File> getImageFile(String assetId) async {
    final file = await _galleryDataSource.getImageFile(assetId);

    if (file == null) {
      throw FileSystemException('File not found for assetId $assetId');
    }

    return file;
  }

  @override
  Future<MediaAsset> getImageMetadata(String assetId) {
    return _galleryDataSource.getImageMetadata(assetId);
  }

  @override
  Future<List<MediaAsset>> getAllMetadata() async {
    final List<AssetEntity> allImageAssets = await _galleryDataSource
        .getAllImages();

    return allImageAssets.map((asset) {
      return fillMetadataFromAsset(asset);
    }).toList();
  }

  @override
  Future<bool> moveMediaToTrash(List<String> assetIds) {
    // TODO: implement moveMediaToTrash
    throw UnimplementedError();
  }

  @override
  Future<List<MediaAsset>> readAlbum({
    required String albumId,
    required int page,
    int limit = 50,
  }) async {
    final List<AssetEntity> albumImageAssets = await _galleryDataSource
        .getImagesFromAlbum(albumId: albumId, page: page, limit: limit);

    return albumImageAssets.map((asset) {
      return MediaAsset(
        assetId: asset.id,
        title: asset.title!,
        createDateTime: asset.createDateTime,
        modifiedDateTime: asset.modifiedDateTime,
        mediaType: asset.type == AssetType.image
            ? EMediaType.image
            : EMediaType.video,
      );
    }).toList();
  }

  @override
  Future<bool> createAlbum(String albumName) async {
    return await _galleryDataSource.createAlbum(albumName);
  }

  @override
  Future<bool> moveMediaToAlbum(
    List<String> assetIds,
    String targetAlbumId,
  ) async {
    // TODO: implement deleteAlbum
    throw UnimplementedError();
  }

  @override
  Future<bool> deleteAlbum(String albumId) async {
    // TODO: implement deleteAlbum
    throw UnimplementedError();
  }
}

final galleryRepository = GalleryRepository(GalleryDataSource());

final galleryRepositoryProvider = Provider((ref) {
  final dataSource = ref.watch(galleryDataSourceProvider);
  return GalleryRepository(dataSource);
});
