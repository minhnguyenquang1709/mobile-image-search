import 'dart:collection';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_image_search/src/core/constants/config_constant.dart';
import 'package:mobile_image_search/src/data/interfaces/media_asset_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_details.dart';
import 'package:mobile_image_search/src/core/utils/exceptions.dart';
import 'package:mobile_image_search/src/core/utils/media_processing.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class MediaAssetRepository implements IMediaAssetRepository {
  // in-memory cache
  final HashMap<String, AssetEntity> _assetEntityCache =
      HashMap<String, AssetEntity>();

  HashMap<String, AssetEntity> get assetEntityCache => _assetEntityCache;

  @override
  Future<bool> requestGalleryAccess() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final int sdkInt = androidInfo.version.sdkInt;

      if (sdkInt < 33) {
        final storagePermission = await Permission.storage.status;
        if (storagePermission.isGranted) {
          return true;
        }
        if (storagePermission.isDenied) {
          final status = await Permission.storage.request();
          return status.isGranted;
        }
        if (storagePermission.isPermanentlyDenied ||
            storagePermission.isRestricted) {
          await openAppSettings();
          final newStatus = await Permission.storage.status;
          return newStatus.isGranted;
        }
        return false;
      }

      final statuses = await [Permission.photos, Permission.videos].request();
      final photosGranted = statuses[Permission.photos]?.isGranted ?? false;
      final videosGranted = statuses[Permission.videos]?.isGranted ?? false;
      if (photosGranted && videosGranted) {
        return true;
      }
      if (statuses[Permission.photos]!.isPermanentlyDenied ||
          statuses[Permission.videos]!.isPermanentlyDenied) {
        await openAppSettings();
        return await _checkGalleryPermission();
      }
      return false;
    }

    if (Platform.isIOS) {
      final photoStorage = await Permission.photos.status;
      if (photoStorage.isGranted) {
        return true;
      }
      if (photoStorage.isDenied) {
        final status = await Permission.photos.request();
        return status.isGranted;
      }
      if (photoStorage.isPermanentlyDenied || photoStorage.isRestricted) {
        await openAppSettings();
        final newStatus = await Permission.photos.status;
        return newStatus.isGranted;
      }
    }

    return false;
  }

  Future<bool> _checkGalleryPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final int sdkInt = androidInfo.version.sdkInt;

      if (sdkInt < 33) {
        return await Permission.storage.isGranted;
      }
      return await Permission.photos.isGranted &&
          await Permission.videos.isGranted;
    } else if (Platform.isIOS) {
      return await Permission.photos.isGranted;
    }
    throw UnsupportedError(
      'Unsupported platform. The supported platforms are Android and iOS.',
    );
  }

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

    return _toMediaAssetList(assetPage);
  }

  List<MediaAsset> _toMediaAssetList(List<AssetEntity> entities) {
    return entities.map((assetEntity) {
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

    return _toMediaAssetList(assetPage);
  }

  Future<AssetEntity> _loadEntity(String assetId) async {
    final cached = _assetEntityCache[assetId];
    if (cached != null) return cached;

    final AssetEntity? assetEntity = await AssetEntity.fromId(assetId);
    if (assetEntity == null) {
      throw MediaAssetNotFoundException("Asset with ID $assetId not found");
    }
    _assetEntityCache[assetId] = assetEntity;
    return assetEntity;
  }

  @override
  Future<MediaAsset> getMediaAssetById(String assetId) async {
    final assetEntity = await _loadEntity(assetId);
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

  @override
  Future<ImageProvider> fullResolutionProviderFor(String assetId) async {
    final assetEntity = await _loadEntity(assetId);
    return AssetEntityImageProvider(assetEntity, isOriginal: true);
  }

  @override
  Future<File> getVideoFile(String assetId) async {
    final assetEntity = await _loadEntity(assetId);
    final file = await assetEntity.file;
    if (file == null) {
      throw MediaAssetNotFoundException("File for asset $assetId not found");
    }
    return file;
  }

  @override
  Future<MediaDetails> getMediaDetails(String assetId) async {
    final assetEntity = await _loadEntity(assetId);

    final file = await assetEntity.file;
    final size = await file?.length();

    // relativePath example: "DCIM/A/"
    String? albumName;
    final relativePath = assetEntity.relativePath;
    if (relativePath != null && relativePath.isNotEmpty) {
      final segments = relativePath.split('/').where((s) => s.isNotEmpty);
      if (segments.isNotEmpty) albumName = segments.last;
    }

    return MediaDetails(sizeBytes: size, albumName: albumName);
  }
}
