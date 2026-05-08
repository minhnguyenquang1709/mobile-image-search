import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/src/constants/config_constant.dart';
import 'package:mobile_image_search/src/constants/theme_constant.dart';
import 'package:mobile_image_search/src/constants/route_constant.dart';
import 'package:mobile_image_search/src/utils/string.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

class ThumbnailWidget extends ConsumerStatefulWidget {
  final MediaAsset mediaAsset;
  final Function? onTap;
  final Function? onLongPress;

  const ThumbnailWidget({
    super.key,
    required this.mediaAsset,
    this.onTap,
    this.onLongPress,
  });

  @override
  ConsumerState<ThumbnailWidget> createState() => _ThumbnailWidgetState();
}

class _ThumbnailWidgetState extends ConsumerState<ThumbnailWidget>
    with AutomaticKeepAliveClientMixin {
  late Future<AssetEntity?> _assetEntityFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // platform channel call, leading to many calls on the screen with thumbnail list (bottleneck). UI should not fetch data like this. UI should only receive rich data from provider and display it
    _assetEntityFuture = AssetEntity.fromId(widget.mediaAsset.assetId);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return FutureBuilder(
      future: _assetEntityFuture,
      builder: (context, snapshot) {
        // loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          // skeleton placeholder
          // if (media.mediaType == EMediaType.video) {
          //   return const Center(child: Icon(Icons.videocam));
          // }
          return const Center(child: Icon(Icons.image));
        }

        // error
        if (snapshot.hasError) {
          return const Center(child: Text("Failed to load image"));
        }

        if (snapshot.data == null) {
          return const Center(child: Text("Image not found"));
        }

        final AssetEntity assetEntity = snapshot.data!;
        final MediaAsset mediaAsset = widget.mediaAsset;
        return GestureDetector(
          onTap: () {
            // context.push(
            //   RouteConstants.mediaView,
            //   extra: {'media': widget.mediaAsset},
            // );
            if (widget.onTap != null) {
              widget.onTap!(mediaAsset);
            }
          },
          onLongPress: () {
            if (widget.onLongPress != null) {
              widget.onLongPress!();
            }
          },
          child: RepaintBoundary(
            child: Builder(
              builder: (context) {
                final assetEntityImageWidget = AssetEntityImage(
                  assetEntity,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) {
                      return child;
                    }
                    return const Center(child: Icon(Icons.image));
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      const Center(child: Icon(Icons.error)),
                  isOriginal: false, // use thumbnail instead of original image
                  fit: BoxFit.cover,
                  thumbnailSize: const ThumbnailSize(
                    UIConfig.thumbnailWidth,
                    UIConfig.thumbnailHeight,
                  ),
                );

                final bool isVideo = mediaAsset is VideoAsset;
                final stack = Stack(
                  children: [
                    Positioned.fill(child: assetEntityImageWidget),

                    if (isVideo && mediaAsset.duration > 0)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.only(left: 5, right: 5),
                          decoration: BoxDecoration(
                            color: CustomColors.surface.withAlpha(200),
                            borderRadius: BorderRadius.circular(99.0),
                          ),
                          child: SizedBox.fromSize(
                            size: const Size(40, 20),
                            child: Center(
                              child: Text(
                                formatVideoDuration(mediaAsset.duration),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: CustomColors.textSecondary,
                                  fontFamily: CustomTextStyles.fontFamily,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );

                return stack;
              },
            ),
          ),
        );
      },
    );
  }
}
