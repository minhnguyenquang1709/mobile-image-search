import 'package:mobile_image_search/src/constants/common_constant.dart';

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
  final EMediaType mediaType;
  int duration;

  MediaAsset({
    required this.assetId,
    required this.title,
    required this.createDateTime,
    required this.modifiedDateTime,
    required this.mediaType,
    this.duration = 0,
  });
}

class MediaGroup {
  final List<MediaAsset> mediaItems;
  final DateTime date;

  MediaGroup({required this.date, required this.mediaItems});
}
