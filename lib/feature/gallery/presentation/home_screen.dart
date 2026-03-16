import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/core/config/config.dart';
import 'package:mobile_image_search/feature/gallery/presentation/gallery_controller.dart';
import 'package:mobile_image_search/feature/gallery/presentation/image_widget.dart';
import 'package:mobile_image_search/feature/gallery/presentation/selection_controller.dart';
import 'package:mobile_image_search/shared/domain/image_model.dart';

class SelectionStatusBar extends StatelessWidget {
  final int selectedCount;
  const SelectionStatusBar({super.key, required this.selectedCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: Text(
        '$selectedCount selected',
        style: const TextStyle(color: Colors.black, fontSize: 16),
      ),
    );
  }
}

class ImageGroupWidget extends StatelessWidget {
  final ImageGroup imageGroup;
  const ImageGroupWidget({super.key, required this.imageGroup});

  @override
  Widget build(BuildContext context) {
    // date
    final SliverToBoxAdapter dateHeader = SliverToBoxAdapter(
      child: Text(imageGroup.date.toString().split(' ')[0]),
    );

    // image grid
    final SliverGrid imageGrid = SliverGrid(
      delegate: SliverChildBuilderDelegate((context, index) {
        return ThumbnailWidget(image: imageGroup.images[index]);
      }, childCount: imageGroup.images.length),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Config.imagesPerRow,
        crossAxisSpacing: Config.crossAxisSpacing,
        mainAxisSpacing: Config.mainAxisSpacing,
      ),
    );

    // spacing to next group
    const spacing = SliverToBoxAdapter(
      child: SizedBox(height: Config.imageGroupSpacing),
    );

    return SliverList(
      delegate: SliverChildListDelegate([dateHeader, imageGrid, spacing]),
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
        error: (err, stack) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(child: Text("Error loading images: $err")),
            TextButton(
              child: const Text("Request Permission or Refresh"),
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

          final selectedImages = ref.watch(selectionControllerProvider);

          // UI rebuild optimization: flatten image group list
          final imageGroupWidgetList = imageGroups
              .map((group) => ImageGroupWidget(imageGroup: group))
              .toList();

          final fullScreenImageList = Flex(
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
                      slivers: imageGroupWidgetList,
                      scrollDirection: Axis.vertical,
                    ),
                  ),
                ),
              ),
            ],
          );

          final selectionStatusBar = SelectionStatusBar(
            selectedCount: selectedImages.length,
          );

          final stack = Stack(
            children: [
              fullScreenImageList,
              if (selectedImages.isNotEmpty) selectionStatusBar,
            ],
          );

          return stack;
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
