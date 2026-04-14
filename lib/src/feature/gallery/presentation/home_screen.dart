import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/constants/config_constant.dart';
import 'package:mobile_image_search/src/constants/theme_constant.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/gallery_controller.dart';
import 'package:mobile_image_search/src/common_widgets/image_widget.dart';
import 'package:mobile_image_search/src/shared/domain/model/media.dart';

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
  final MediaGroup _imageGroup;
  const ImageGroupWidget({super.key, required MediaGroup imageGroup})
    : _imageGroup = imageGroup;

  @override
  Widget build(BuildContext context) {
    // date
    final SliverToBoxAdapter dateHeader = SliverToBoxAdapter(
      child: Text(_imageGroup.date.toString().split(' ')[0]),
    );

    // image grid
    final SliverGrid imageGrid = SliverGrid(
      delegate: SliverChildBuilderDelegate((context, index) {
        return ThumbnailWidget(
          assetId: _imageGroup.mediaItems[index].assetId,
          key: Key(_imageGroup.mediaItems[index].assetId),
        );
      }, childCount: _imageGroup.mediaItems.length),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: UIConfig.imagesPerRow,
        crossAxisSpacing: UIConfig.crossAxisSpacing,
        mainAxisSpacing: UIConfig.mainAxisSpacing,
      ),
    );

    // spacing to next group
    const spacing = SliverToBoxAdapter(
      child: SizedBox(height: UIConfig.imageGroupSpacing),
    );

    return SliverMainAxisGroup(slivers: [dateHeader, imageGrid, spacing]);
  }
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTopButton = false;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 500) {
        ref.read(galleryControllerProvider.notifier).loadMore();
        setState(() {
          _showScrollToTopButton = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _showScrollToTopButton = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final galleryController = ref.watch(galleryControllerProvider);

    return Container(
      child: galleryController.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(child: Text("Error loading images: $err")),
            TextButton(
              child: const Text("Request Permission or Refresh"),
              onPressed: () {
                final _ = ref.refresh(galleryControllerProvider);
              },
            ),
          ],
        ),
        data: (imageGroups) {
          if (imageGroups.isEmpty) {
            return const Center(child: Text("No images found in gallery"));
          }

          // TODO: optimize this, currently it rebuilds the whole list when selection changes, which is not ideal for performance
          // this is eager loading, causes performance issue when the list is big
          final imageGroupWidgetList = imageGroups
              .map(
                (group) => ImageGroupWidget(
                  imageGroup: group,
                  key: ValueKey(group.date),
                ),
              )
              .toList();

          final fullScreenImageList = Flex(
            direction: Axis.vertical,
            children: [
              Expanded(
                child: RawScrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  thumbColor: CustomColors.primary,
                  thickness: 20,
                  radius: const Radius.circular(40),
                  // padding: const EdgeInsets.only(top: 10),
                  minThumbLength: UIConfig.homeScreenScrollbarThumbMinHeight,
                  interactive: true,
                  crossAxisMargin: UIConfig.gridViewGutter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: UIConfig.gridViewGutter,
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

          final stack = Stack(
            children: [
              fullScreenImageList,

              if (_showScrollToTopButton)
                Align(
                  alignment: AlignmentGeometry.bottomCenter,
                  child: ElevatedButton(
                    onPressed: _scrollToTop,
                    child: Icon(Icons.arrow_upward),
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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}
