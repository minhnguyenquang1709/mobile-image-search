import 'package:mobile_image_search/shared/domain/interface/image_interface.dart';
import 'package:photo_manager/photo_manager.dart';

class Image {
  /// The ID of the asset.
  ///
  /// - Android: _id column in MediaStore database.
  ///
  /// - iOS/macOS: localIdentifier.
  final AssetEntity assetEntity;
  final IImageMetadata metadata;

  Image({required this.assetEntity, required this.metadata});
}
