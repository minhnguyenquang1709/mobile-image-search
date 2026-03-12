import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/core/config/config.dart';
import 'package:mobile_image_search/core/constants/route.constant.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:mobile_image_search/shared/domain/image_model.dart'
    as image_model;

class ThumbnailWidget extends StatefulWidget {
  final image_model.Image image;
  final Function(String assetId)? onTap;

  const ThumbnailWidget({super.key, required this.image, this.onTap});

  @override
  State<ThumbnailWidget> createState() => _ThumbnailWidgetState();
}

class _ThumbnailWidgetState extends State<ThumbnailWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final assetEntity = widget.image.assetEntity;
    return GestureDetector(
      onTap: () {
        context.push(
          RouteConstants.imageViewer,
          extra: {'assetEntity': assetEntity},
        );
        if (widget.onTap != null) {
          widget.onTap!(assetEntity.id);
        }
      },
      child: AssetEntityImage(
        assetEntity,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) =>
            const Center(child: Icon(Icons.error)),
        isOriginal: false, // use thumbnail instead of original image
        fit: BoxFit.cover,
        thumbnailSize: const ThumbnailSize(
          Config.thumbnailWidth,
          Config.thumbnailHeight,
        ),
      ),
    );
  }
}
