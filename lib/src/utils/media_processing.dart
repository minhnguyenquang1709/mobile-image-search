import 'package:mobile_image_search/src/constants/common_constant.dart';
import 'package:mobile_image_search/src/shared/domain/model/media.dart';
import 'package:photo_manager/photo_manager.dart';

Media fillMetadataFromAsset(AssetEntity asset) {
  return Media(
    assetId: asset.id,
    name: asset.title!,
    createDateTime: asset.createDateTime,
    modifiedDateTime: asset.modifiedDateTime,
    mediaType: asset.type == AssetType.image
        ? EMediaType.image
        : EMediaType.video,
    duration: asset.duration,
  );
}

bool isSameMedia(Media metadata1, Media metadata2) {
  return metadata1.name == metadata2.name &&
      metadata1.createDateTime == metadata2.createDateTime &&
      metadata1.modifiedDateTime == metadata2.modifiedDateTime &&
      metadata1.mediaType == metadata2.mediaType &&
      metadata1.duration == metadata2.duration;
}
