import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/core/config/config.dart';
import 'package:mobile_image_search/core/constants/route.constant.dart';
import 'package:mobile_image_search/service/gallery.service.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class ThumbnailWidget extends StatefulWidget {
  final String assetId;

  const ThumbnailWidget({super.key, required this.assetId});

  @override
  State<ThumbnailWidget> createState() => _ThumbnailWidgetState();
}

class _ThumbnailWidgetState extends State<ThumbnailWidget> {
  AssetEntity? assetEntity;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // load asset entity and cache in state
    AssetEntity.fromId(widget.assetId)
        .then((entity) {
          setState(() {
            assetEntity = entity;
            _isLoading = false;
          });
        })
        .catchError((error) {
          setState(() {
            assetEntity = null;
            _isLoading = false;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (assetEntity == null) {
      return const Center(child: Icon(Icons.error));
    }
    return GestureDetector(
      onTap: () => context.push(
        RouteConstants.imageViewer,
        extra: {'assetId': widget.assetId},
      ),
      child: AssetEntityImage(
        assetEntity!,
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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imagesAsync = ref.watch(galleryImagesProvider);

    return imagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text("Error loading images: $err")),
      data: (images) {
        if (images.isEmpty) {
          return const Center(child: Text("No images found in gallery"));
        }
        return Scaffold(
          // appBar: AppBar(title: Text("Home")),
          body: Flex(
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
                            return ThumbnailWidget(assetId: images[index].id);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
