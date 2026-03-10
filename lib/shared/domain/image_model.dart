import 'package:mobile_image_search/shared/domain/interface/image_interface.dart';

class Image {
  /// The ID of the asset.
  ///
  /// - Android: _id column in MediaStore database.
  ///
  /// - iOS/macOS: localIdentifier.
  final String assetId;
  final IImageMetadata metadata;

  Image({required this.assetId, required this.metadata});
}
