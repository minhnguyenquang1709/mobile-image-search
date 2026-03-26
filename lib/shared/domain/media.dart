import 'package:mobile_image_search/shared/domain/interface/image_interface.dart';

class Media {
  /// The ID of the asset.
  ///
  /// - Android: _id column in MediaStore database.
  ///
  /// - iOS/macOS: localIdentifier.
  final String assetId;
  final IMediaMetadata metadata;

  Media({required this.assetId, required this.metadata});
}

class MediaGroup {
  final List<Media> mediaItems;
  final DateTime date;

  MediaGroup({required this.date, required this.mediaItems});
}
