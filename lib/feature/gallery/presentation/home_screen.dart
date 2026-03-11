import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/core/config/config.dart';
import 'package:mobile_image_search/core/constants/route.constant.dart';
import 'package:mobile_image_search/feature/gallery/presentation/gallery_controller.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:mobile_image_search/shared/domain/image_model.dart'
    as image_model;

class ThumbnailWidget extends StatefulWidget {
  final image_model.Image image;
  final Future<void> Function(String assetId)? onTap;

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
          extra: {'assetId': assetEntity.id},
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

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 500) {
        ref.read(galleryControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final galleryController = ref.watch(galleryControllerProvider);

    return Scaffold(
      body: galleryController.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text("Error loading images: $err")),
        data: (images) {
          if (images.isEmpty) {
            return const Center(child: Text("No images found in gallery"));
          }

          return Flex(
            direction: Axis.vertical,
            children: [
              Expanded(
                child: Center(
                  child: Builder(
                    builder: (context) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          left: Config.gridViewGutter,
                          right: Config.gridViewGutter,
                        ),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: Config.imagesPerRow,
                                crossAxisSpacing: Config.crossAxisSpacing,
                                mainAxisSpacing: Config.mainAxisSpacing,
                              ),
                          cacheExtent: Config.gridViewCacheExtent,
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            return ThumbnailWidget(image: images[index]);
                          },
                          controller: _scrollController,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}
