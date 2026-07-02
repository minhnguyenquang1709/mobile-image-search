import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_details.dart';

/// CRUD operations for media asset data
abstract class IMediaAssetRepository {
  Future<List<MediaAsset>> fetchPage({
    required int page,
    required int pageSize,
  });

  Future<List<MediaAsset>> fetchPageFiltered({
    required int page,
    required int pageSize,
    DateTime? rangeStart,
    DateTime? rangeEnd,
  });

  Future<List<MediaAsset>> fetchAlbumPage({
    required String albumId,
    required int page,
    required int pageSize,
  });

  Future<MediaAsset> getMediaAssetById(String assetId);

  ImageProvider thumbnailProviderFor(String assetId);

  Future<ImageProvider> fullResolutionProviderFor(String assetId);

  Future<File> getVideoFile(String assetId);

  Future<MediaDetails> getMediaDetails(String assetId);
}
