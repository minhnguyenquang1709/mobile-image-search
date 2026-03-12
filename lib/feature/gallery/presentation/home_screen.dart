import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/core/config/config.dart';
import 'package:mobile_image_search/feature/gallery/presentation/gallery_controller.dart';
import 'package:mobile_image_search/feature/gallery/presentation/image_widget.dart';

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
        error: (err, stack) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(child: Text("Error loading images: $err")),
            TextButton(
              child: const Text("Request Permission"),
              onPressed: () {
                ref.refresh(galleryControllerProvider);
              },
            ),
          ],
        ),
        data: (imageGroups) {
          if (imageGroups.isEmpty) {
            return const Center(child: Text("No images found in gallery"));
          }
          return Flex(
            direction: Axis.vertical,
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Config.gridViewGutter,
                    ),
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: imageGroups.map((group) {
                        return SliverMainAxisGroup(
                          slivers: [
                            // datetime header
                            SliverToBoxAdapter(
                              child: Text(group.date.toString().split(' ')[0]),
                            ),

                            // image grid
                            SliverGrid(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                return ThumbnailWidget(
                                  image: group.images[index],
                                );
                              }, childCount: group.images.length),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: Config.imagesPerRow,
                                    crossAxisSpacing: Config.crossAxisSpacing,
                                    mainAxisSpacing: Config.mainAxisSpacing,
                                  ),
                            ),

                            // ending space
                            const SliverToBoxAdapter(
                              child: SizedBox(height: Config.imageGroupSpacing),
                            ),
                          ],
                        );
                      }).toList(),
                      scrollDirection: Axis.vertical,
                    ),
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
