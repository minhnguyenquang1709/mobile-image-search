import 'package:mobile_image_search/src/constants/common_constant.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:photo_manager/photo_manager.dart';

MediaAsset fillMetadataFromAsset(AssetEntity asset) {
  return MediaAsset(
    assetId: asset.id,
    title: asset.title!,
    createDateTime: asset.createDateTime,
    modifiedDateTime: asset.modifiedDateTime,
    mediaType: asset.type == AssetType.image
        ? EMediaType.image
        : EMediaType.video,
    duration: asset.duration,
  );
}

bool isSameMedia(MediaAsset metadata1, MediaAsset metadata2) {
  return metadata1.title == metadata2.title &&
      metadata1.createDateTime == metadata2.createDateTime &&
      metadata1.modifiedDateTime == metadata2.modifiedDateTime &&
      metadata1.mediaType == metadata2.mediaType &&
      metadata1.duration == metadata2.duration;
}
