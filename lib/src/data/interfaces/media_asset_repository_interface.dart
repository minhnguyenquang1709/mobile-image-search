import 'package:flutter/widgets.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

/// CRUD operations for media asset data
abstract class IMediaAssetRepository {
  Future<List<MediaAsset>> fetchPage({
    required int page,
    required int pageSize,
  });

  /// Like [fetchPage] but pushes an explicit capture-date range down to the
  /// device query. Only the range is pushable; other filters are applied later
  /// in memory.
  Future<List<MediaAsset>> fetchPageFiltered({
    required int page,
    required int pageSize,
    DateTime? rangeStart,
    DateTime? rangeEnd,
  });

  /// Like [fetchPage] but reads a single album instead of the root
  /// album.
  Future<List<MediaAsset>> fetchAlbumPage({
    required String albumId,
    required int page,
    required int pageSize,
  });

  Future<MediaAsset> getMediaAssetById(String assetId);

  ImageProvider thumbnailProviderFor(String assetId);
}
