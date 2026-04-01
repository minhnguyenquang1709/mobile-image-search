import 'package:mobile_image_search/src/constants/common_constant.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_metadata.dart';

class Media {
  /// The ID of the asset.
  ///
  /// - Android: _id column in MediaStore database.
  ///
  /// - iOS/macOS: localIdentifier.
  final String assetId;
  final String name;
  final DateTime createDateTime;
  final DateTime modifiedDateTime;
  final EMediaType mediaType;
  int duration;

  Media({
    required this.assetId,
    required this.name,
    required this.createDateTime,
    required this.modifiedDateTime,
    required this.mediaType,
    this.duration = 0,
  });
}

class MediaGroup {
  final List<Media> mediaItems;
  final DateTime date;

  MediaGroup({required this.date, required this.mediaItems});
}
