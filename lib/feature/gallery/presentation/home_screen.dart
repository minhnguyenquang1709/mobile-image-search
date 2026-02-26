import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/config/config.dart';
import 'package:mobile_image_search/core/constants/route.constant.dart';
import 'package:mobile_image_search/service/gallery_service.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class ThumbnailWidget extends StatelessWidget {
  final String assetId;

  const ThumbnailWidget({super.key, required this.assetId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: AssetEntity.fromId(assetId),
      builder: (context, snapshot) {
        // loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: Config.thumbnailWidth.toDouble(),
            height: Config.thumbnailHeight.toDouble(),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        // error state
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const Center(child: Icon(Icons.error));
        }

        // successful state
        final assetEntity = snapshot.data!;
        return GestureDetector(
          onTap: () => context.push(
            RouteConstants.imageViewer,
            extra: {'assetId': assetId},
          ),
          child: AssetEntityImage(
            assetEntity,
            isOriginal: false, // use thumbnail instead of original image
            thumbnailSize: const ThumbnailSize(
              Config.thumbnailWidth,
              Config.thumbnailHeight,
            ),
          ),
        );
      },
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imagesAsync = ref.watch(galleryImagesProvider);

    return imagesAsync.when(
      loading: () => const Center(),
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
