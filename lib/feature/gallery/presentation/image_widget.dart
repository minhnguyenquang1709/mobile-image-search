import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/core/config/config.dart';
import 'package:mobile_image_search/core/constants/route.constant.dart';
import 'package:mobile_image_search/feature/gallery/presentation/selection_controller.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:mobile_image_search/shared/domain/image_model.dart'
    as image_model;

class ThumbnailWidget extends ConsumerStatefulWidget {
  final image_model.Image image;
  final Function(String assetId)? onTap;

  const ThumbnailWidget({super.key, required this.image, this.onTap});

  @override
  ConsumerState<ThumbnailWidget> createState() => _ThumbnailWidgetState();
}

class _ThumbnailWidgetState extends ConsumerState<ThumbnailWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final assetEntity = widget.image.assetEntity;
    final isImageSelected = ref
        .watch(selectionControllerProvider)
        .contains(assetEntity.id);

    return GestureDetector(
      onTap: () {
        final isInSelectionMode = ref
            .read(selectionControllerProvider)
            .isNotEmpty;
        if (isInSelectionMode) {
          isImageSelected
              ? ref
                    .read(selectionControllerProvider.notifier)
                    .deselectImage(assetEntity.id)
              : ref
                    .read(selectionControllerProvider.notifier)
                    .selectImage(assetEntity.id);
        } else {
          context.push(
            RouteConstants.imageViewer,
            extra: {'image': widget.image},
          );
          if (widget.onTap != null) {
            widget.onTap!(assetEntity.id);
          }
        }
      },
      onLongPress: () {
        final selectionController = ref.read(
          selectionControllerProvider.notifier,
        );
        if (!isImageSelected) {
          selectionController.selectImage(assetEntity.id);
        }
      },
      child: Builder(
        builder: (context) {
          final assetEntityImage = AssetEntityImage(
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
              Config.thumbnailWidth,
              Config.thumbnailHeight,
            ),
          );

          final stack = Stack(
            children: [
              Positioned.fill(child: assetEntityImage),
              Container(
                color: isImageSelected
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
              if (isImageSelected)
                const Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.blueAccent,
                    size: 24,
                  ),
                ),
            ],
          );

          return stack;
        },
      ),
    );
  }
}
