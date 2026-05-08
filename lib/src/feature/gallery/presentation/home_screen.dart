import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/src/common_widgets/thumbnail_widget.dart';
import 'package:mobile_image_search/src/constants/config_constant.dart';
import 'package:mobile_image_search/src/constants/route_constant.dart';
import 'package:mobile_image_search/src/constants/theme_constant.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/gallery_controller.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:mobile_image_search/src/utils/debug.dart';

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  final ValueNotifier<bool> _showTopButton = ValueNotifier(false);

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      final pixels = _scrollController.position.pixels;
      final bool nextValue = pixels >= 120
          ? true
          : (pixels <= 60 ? false : _showTopButton.value);

      if (nextValue != _showTopButton.value) {
        _showTopButton.value = nextValue;
      }

      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 500) {
        ref.read(galleryControllerProvider.notifier).loadMore();
      }

      // final shouldShowButton = _scrollController.position.pixels >= 100;
      // if (shouldShowButton != _showScrollToTopButton) {
      //   setState(() {
      //     _showScrollToTopButton = shouldShowButton;
      //   });
      // }
    });
  }

  @override
  void dispose() {
    _showTopButton.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  List<Widget> _buildGroupSlivers(
    List<DailyMediaGroup> mediaGroups,
    GalleryState state,
  ) {
    final slivers = <Widget>[];

    for (final group in mediaGroups) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(group.datetime.toString().split(' ')[0]),
          ),
        ),
      );

      slivers.add(
        SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: UIConfig.thumbnailsPerRow,
            crossAxisSpacing: UIConfig.gridCrossAxisSpacing,
            mainAxisSpacing: UIConfig.gridMainAxisSpacing,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final mediaAsset = group.mediaAssets[index];
            final thumbnail = ThumbnailWidget(
              mediaAsset: mediaAsset,
              key: ValueKey(mediaAsset.assetId),
            );

            final isSelected = state.selectedAssetIds.contains(
              mediaAsset.assetId,
            );
            final isSelectionMode = state.isSelectionMode;
            final selectionOverlay = GestureDetector(
              child: Container(
                color: isSelected
                    ? Colors.blue.withAlpha(100)
                    : Colors.transparent,
              ),
              onLongPress: () {
                ref
                    .read(galleryControllerProvider.notifier)
                    .toggleSelectMedia(mediaAsset.assetId);
              },
              onTap: () {
                if (isSelectionMode) {
                  ref
                      .read(galleryControllerProvider.notifier)
                      .toggleSelectMedia(mediaAsset.assetId);
                } else {
                  context.push(
                    RouteConstants.mediaView,
                    extra: {'media': mediaAsset},
                  );
                }
              },
            );

            final stack = Stack(children: [thumbnail, selectionOverlay]);

            return stack;
          }, childCount: group.mediaAssets.length),
        ),
      );
    }

    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    final galleryState = ref.watch(galleryControllerProvider);

    return Scaffold(
      body: Container(
        child: galleryState.when(
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
          data: (GalleryState state) {
            final mediaGroups = state.mediaGroups;

            if (mediaGroups.isEmpty) {
              return const Center(child: Text("No images found in gallery"));
            }

            // final mediaGroupSliverList = SliverList(
            //   delegate: SliverChildBuilderDelegate((context, index) {
            //     final DailyMediaGroup group = mediaGroups[index];
            //     return DailyMediaGroupWidget(
            //       mediaGroup: group,
            //       key: ValueKey(group.datetime),
            //     );
            //   }, childCount: mediaGroups.length),
            // );

            final fullScreenImageList = Flex(
              direction: Axis.vertical,
              children: [
                Expanded(
                  child: RawScrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    thumbColor: CustomColors.primary,
                    thickness: 20, // thumb width
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
                        slivers: _buildGroupSlivers(mediaGroups, state),
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

                ValueListenableBuilder<bool>(
                  valueListenable: _showTopButton,
                  builder: (context, visible, _) {
                    return Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        ignoring: !visible,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 120),
                          opacity: visible ? 1 : 0,
                          child: Center(
                            child: ElevatedButton(
                              onPressed: _scrollToTop,
                              child: const Icon(Icons.arrow_upward),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                if (isDebugOrProfileMode)
                  Positioned(
                    top: 40,
                    right: 20,
                    child: ElevatedButton(
                      onPressed: () {
                        ref
                            .read(galleryControllerProvider.notifier)
                            .moveSelectedToTrash();
                      },
                      child: const Text("Move to Trash"),
                    ),
                  ),
              ],
            );

            return stack;
          },
        ),
      ),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}
