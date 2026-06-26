import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:mobile_image_search/src/core/constants/config_constant.dart';
import 'package:mobile_image_search/src/data/interfaces/media_asset_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:mobile_image_search/src/core/utils/exceptions.dart';
import 'package:mobile_image_search/src/core/utils/media_processing.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class MediaAssetRepository implements IMediaAssetRepository {
  // in-memory cache
  final HashMap<String, AssetEntity> _assetEntityCache =
      HashMap<String, AssetEntity>();

  HashMap<String, AssetEntity> get assetEntityCache => _assetEntityCache;

  /// Build the device query options (createDate-desc order + titles), optionally
  /// constraining the capture date to an explicit range.
  FilterOptionGroup _buildFilterOptions({
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) {
    final FilterOptionGroup filterOptions = FilterOptionGroup(
      orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
    );
    filterOptions.setOption(
      AssetType.image,
      const FilterOption(needTitle: true),
    );
    filterOptions.setOption(
      AssetType.video,
      const FilterOption(needTitle: true),
    );

    if (rangeStart != null || rangeEnd != null) {
      filterOptions.createTimeCond = DateTimeCond(
        min: rangeStart ?? DateTime.fromMillisecondsSinceEpoch(0),
        max: rangeEnd ?? DateTime.now(),
      );
    }

    return filterOptions;
  }

  /// Shared paging body: read the root album page and cache each entity.
  Future<List<MediaAsset>> _fetchPage({
    required int page,
    required int pageSize,
    required FilterOptionGroup filterOptions,
  }) async {
    // get the root album (all device media)
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true, // only get the root album
      filterOption: filterOptions,
    );

    if (albums.isEmpty) {
      return [];
    }

    final rootAlbum = albums.first;

    final List<AssetEntity> assetPage = await rootAlbum.getAssetListPaged(
      page: page,
      size: pageSize,
    );

    return assetPage.map((AssetEntity assetEntity) {
      _assetEntityCache[assetEntity.id] = assetEntity;
      return toMediaAsset(assetEntity);
    }).toList();
  }

  @override
  Future<List<MediaAsset>> fetchPage({
    required int page,
    required int pageSize,
  }) {
    return _fetchPage(
      page: page,
      pageSize: pageSize,
      filterOptions: _buildFilterOptions(),
    );
  }

  @override
  Future<List<MediaAsset>> fetchPageFiltered({
    required int page,
    required int pageSize,
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) {
    return _fetchPage(
      page: page,
      pageSize: pageSize,
      filterOptions: _buildFilterOptions(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
    );
  }

  @override
  Future<List<MediaAsset>> fetchAlbumPage({
    required String albumId,
    required int page,
    required int pageSize,
  }) async {
    final AssetPathEntity album = await AssetPathEntity.fromId(albumId);

    final List<AssetEntity> assetPage = await album.getAssetListPaged(
      page: page,
      size: pageSize,
    );

    return assetPage.map((AssetEntity assetEntity) {
      _assetEntityCache[assetEntity.id] = assetEntity;
      return toMediaAsset(assetEntity);
    }).toList();
  }

  @override
  Future<MediaAsset> getMediaAssetById(String assetId) async {
    if (_assetEntityCache.containsKey(assetId)) {
      return toMediaAsset(_assetEntityCache[assetId]!);
    }

    final AssetEntity? assetEntity = await AssetEntity.fromId(assetId);
    if (assetEntity == null) {
      throw MediaAssetNotFoundException("Asset with ID $assetId not found");
    }

    _assetEntityCache[assetId] = assetEntity;
    return toMediaAsset(assetEntity);
  }

  @override
  ImageProvider thumbnailProviderFor(String assetId) {
    return AssetEntityImageProvider(
      _assetEntityCache[assetId]!,
      isOriginal: false,
      thumbnailSize: const ThumbnailSize.square(UIConfig.thumbnailWidth),
    );
  }
}
