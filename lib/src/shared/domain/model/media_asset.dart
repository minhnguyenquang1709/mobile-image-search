import 'package:mobile_image_search/src/core/constants/common_constant.dart';

/// Android: https://developer.android.com/media/platform/supported-formats
enum EMediaFormat {
  // image
  jpg,
  png,
  webp,
  gif,

  // video
  mp4,
  mkv,
  webm,

  // unknown
  unknown,
}

enum EStorageLocation { internal, sdCard }

class MediaAsset {
  /// The ID of the asset.
  ///
  /// - Android: _id column in MediaStore database.
  ///
  /// - iOS/macOS: localIdentifier.
  final String assetId;
  final String title;
  final DateTime createDateTime;
  final DateTime modifiedDateTime;
  final int width;
  final int height;
  final EMediaType mediaType;
  final EMediaFormat format;
  bool isFavorite;
  int? sizeBytes;

  MediaAsset({
    required this.assetId,
    required this.title,
    required this.width,
    required this.height,
    required this.createDateTime,
    required this.modifiedDateTime,
    required this.mediaType,
    required this.format,
    this.isFavorite = false,
    this.sizeBytes,
  });
}

class ImageAsset extends MediaAsset {
  ImageAsset({
    required super.assetId,
    required super.title,
    required super.width,
    required super.height,
    required super.createDateTime,
    required super.modifiedDateTime,
    required super.mediaType,
    required super.format,
  });
}

class VideoAsset extends MediaAsset {
  final int duration;
  VideoAsset({
    required super.assetId,
    required super.title,
    required super.width,
    required super.height,
    required super.createDateTime,
    required super.modifiedDateTime,
    required super.mediaType,
    required super.format,
    required this.duration,
  });
}

class DailyMediaGroup {
  final List<MediaAsset> mediaAssets;
  final DateTime datetime;

  DailyMediaGroup({required this.datetime, required this.mediaAssets});
}
