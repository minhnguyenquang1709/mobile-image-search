import 'dart:collection';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/constants/common_constant.dart';
import 'package:mobile_image_search/src/utils/media_processing.dart';
import 'package:mobile_image_search/src/feature/gallery/data/gallery_data_source.dart';
import 'package:mobile_image_search/src/shared/domain/interface/gallery_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:photo_manager/photo_manager.dart';

class AndroidGalleryRepository implements IGalleryRepository {
  final GalleryDataSource _galleryDataSource;

  /// ordered in-memory cache
  static final LinkedHashMap<String, AssetEntity> _assetEntityCache =
      LinkedHashMap<String, AssetEntity>();

  AndroidGalleryRepository(this._galleryDataSource);

  /// Read gallery albums and cache them in memory and record the number of image files
  ///
  /// Return domain model
  @override
  Future<List<MediaAsset>> readGallery({
    required int page,
    int limit = 50,
  }) async {
    final List<AssetEntity> assetEntities = await _galleryDataSource
        .getImagesPaginationSupport(page: page, limit: limit);

    final List<MediaAsset> assets = [];

    for (final AssetEntity asset in assetEntities) {
      try {
        // _addEntityToCache(asset);
        if (asset.type == AssetType.image || asset.type == AssetType.video) {
          final MediaAsset media = toMediaAsset(asset);
          assets.add(media);
        }
      } catch (e) {
        rethrow;
      }
    }

    return assets;
  }

  /// Helper method to add asset entity to cache with LRU eviction
  void _addEntityToCache(AssetEntity asset) {
    if (_assetEntityCache.length > 3000) {
      _assetEntityCache.remove(_assetEntityCache.keys.first);
    }

    _assetEntityCache[asset.id] = asset;
  }

  @override
  Future<bool> requestGalleryAccess() async {
    return await _galleryDataSource.requestGalleryAccess();
  }

  @override
  Future<List<MediaAsset>> getAllMetadata() async {
    final List<AssetEntity> allImageAssets = await _galleryDataSource
        .getAllImages();

    return allImageAssets.map((asset) {
      return toMediaAsset(asset);
    }).toList();
  }

  @override
  Future<bool> moveMediaToTrash(List<MediaAsset> mediaAssets) {
    return _galleryDataSource.moveMediaToTrash(mediaAssets);
  }

  @override
  Future<List<MediaAsset>> readAlbum({
    required String albumId,
    required int page,
    int limit = 50,
  }) async {
    throw UnimplementedError();
    // final List<AssetEntity> albumImageAssets = await _galleryDataSource
    //     .getImagesFromAlbum(albumId: albumId, page: page, limit: limit);

    // return albumImageAssets.map((asset) {
    //   return MediaAsset(
    //     assetId: asset.id,
    //     title: asset.title!,
    //     createDateTime: asset.createDateTime,
    //     modifiedDateTime: asset.modifiedDateTime,
    //     mediaType: asset.type == AssetType.image
    //         ? EMediaType.image
    //         : EMediaType.video, sizeBytes: null, width: null, height: null, format: null, storageLocation: null,
    //   );
    // }).toList();
  }

  @override
  Future<bool> createAlbum(
    String albumName,
    List<MediaAsset> mediaAssets,
  ) async {
    return await _galleryDataSource.createAlbum(albumName, mediaAssets);
  }

  /// Move multiple images or videos to a specific album
  @override
  Future<bool> moveMediaToAlbum(
    List<MediaAsset> mediaAssets,
    String targetAlbumId,
  ) async {
    try {
      bool isSuccess = false;

      isSuccess = await _galleryDataSource.moveMediaToAlbum(
        mediaAssets: mediaAssets,
        targetAlbumId: targetAlbumId,
      );

      return isSuccess;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> deleteAlbum(String albumId, {bool deleteMedia = false}) async {
    // TODO: implement deleteAlbum
    throw UnimplementedError();
  }

  @override
  AssetEntity? getCachedEntity(String assetId) {
    return _assetEntityCache[assetId];
  }

  @override
  Future<MediaAsset> populateAssetDetails(MediaAsset mediaAsset) async {
    // fetch original file
    try {
      AssetEntity? assetEntity = getCachedEntity(mediaAsset.assetId);
      assetEntity ??= await AssetEntity.fromId(mediaAsset.assetId);

      if (assetEntity == null) {
        throw Exception(
          'photo_manager cannot find media asset for id: ${mediaAsset.assetId}',
        );
      }

      final File? file = await assetEntity.file;
      if (file == null) {
        throw Exception(
          'Failed to get file for asset id: ${mediaAsset.assetId}',
        );
      }

      mediaAsset.sizeBytes = await file.length();
      return mediaAsset;
    } catch (e) {
      rethrow;
    }
  }
}

final galleryRepositoryProvider = Provider((ref) {
  final dataSource = ref.watch(galleryDataSourceProvider);
  return AndroidGalleryRepository(dataSource);
});
