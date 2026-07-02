import 'package:mobile_image_search/src/core/constants/common_constant.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:photo_manager/photo_manager.dart';

MediaAsset toMediaAsset(AssetEntity asset) {
  if (asset.type == AssetType.video) {
    return VideoAsset(
      assetId: asset.id,
      title: asset.title!,
      createDateTime: asset.createDateTime,
      modifiedDateTime: asset.modifiedDateTime,
      mediaType: EMediaType.video,
      width: asset.width,
      height: asset.height,
      format: getMediaFormatFromTitle(asset.title!),
      duration: asset.duration,
    );
  }

  return ImageAsset(
    assetId: asset.id,
    title: asset.title!,
    createDateTime: asset.createDateTime,
    modifiedDateTime: asset.modifiedDateTime,
    mediaType: asset.type == AssetType.image
        ? EMediaType.image
        : EMediaType.video,
    width: asset.width,
    height: asset.height,
    format: getMediaFormatFromTitle(asset.title!),
  );
}

EMediaFormat getMediaFormatFromTitle(String title) {
  final extension = title.split('.').last.toLowerCase();
  switch (extension) {
    case 'jpg':
    case 'jpeg':
      return EMediaFormat.jpg;
    case 'png':
      return EMediaFormat.png;
    case 'webp':
      return EMediaFormat.webp;
    case 'gif':
      return EMediaFormat.gif;
    case 'mp4':
      return EMediaFormat.mp4;
    case 'mkv':
      return EMediaFormat.mkv;
    case 'webm':
      return EMediaFormat.webm;
    default:
      return EMediaFormat.unknown;
  }
}

bool isSameMedia(MediaAsset metadata1, MediaAsset metadata2) {
  // return true;
  return metadata1.title == metadata2.title &&
      metadata1.createDateTime == metadata2.createDateTime &&
      metadata1.modifiedDateTime == metadata2.modifiedDateTime &&
      metadata1.mediaType == metadata2.mediaType;
}
