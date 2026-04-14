import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/src/constants/config_constant.dart';
import 'package:mobile_image_search/src/constants/theme_constant.dart';
import 'package:mobile_image_search/src/constants/common_constant.dart';
import 'package:mobile_image_search/src/constants/route_constant.dart';
import 'package:mobile_image_search/src/utils/string.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/selection_controller.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:mobile_image_search/src/shared/domain/model/media.dart';

class ThumbnailWidget extends ConsumerStatefulWidget {
  final String assetId;
  final Function(String assetId)? onTap;

  const ThumbnailWidget({super.key, required this.assetId, this.onTap});

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

    _assetEntityFuture = AssetEntity.fromId(widget.assetId);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isImageSelected = ref.watch(
      selectionControllerProvider.select(
        (state) => state.contains(widget.assetId),
      ),
    );
    final assetId = widget.assetId;

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
        final MediaAsset mediaAsset = MediaAsset(
          assetId: assetId,
          title: assetEntity.title!,
          createDateTime: assetEntity.createDateTime,
          modifiedDateTime: assetEntity.modifiedDateTime,
          mediaType: assetEntity.type == AssetType.video
              ? EMediaType.video
              : EMediaType.image,
          duration: assetEntity.duration,
        );
        return GestureDetector(
          onTap: () {
            final isInSelectionMode = ref
                .read(selectionControllerProvider)
                .isNotEmpty;
            if (isInSelectionMode) {
              isImageSelected
                  ? ref
                        .read(selectionControllerProvider.notifier)
                        .deselectImage(assetId)
                  : ref
                        .read(selectionControllerProvider.notifier)
                        .selectImage(assetId);
            } else {
              context.push(
                RouteConstants.mediaViewer,
                extra: {'image': widget.assetId},
              );
              if (widget.onTap != null) {
                widget.onTap!(assetId);
              }
            }
          },
          onLongPress: () {
            final selectionController = ref.read(
              selectionControllerProvider.notifier,
            );
            if (!isImageSelected) {
              selectionController.selectImage(assetId);
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

                final bool isVideo = mediaAsset.mediaType == EMediaType.video;
                final stack = Stack(
                  children: [
                    Positioned.fill(child: assetEntityImageWidget),
                    Container(
                      color: isImageSelected
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.transparent,
                    ),
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
                    if (isImageSelected)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(
                          Icons.check_circle,
                          color: lightTheme.colorScheme.primary,
                          size: 24,
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
