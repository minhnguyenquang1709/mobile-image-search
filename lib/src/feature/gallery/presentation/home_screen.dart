import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/src/common_widgets/thumbnail_widget.dart';
import 'package:mobile_image_search/src/constants/config_constant.dart';
import 'package:mobile_image_search/src/constants/route_constant.dart';
import 'package:mobile_image_search/src/constants/theme_constant.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/gallery_view_model.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/trash_view_model.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:mobile_image_search/src/utils/debug.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _showTopButton = ValueNotifier(false);

  @override
  void initState() {
    super.initState();

    // Load initial gallery data
    _loadGalleryData();

    // Pagination listener
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadGalleryData() async {
    try {
      await GalleryViewModel.instance.loadInitial();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading gallery: $e')));
      }
    }
  }

  void _onScroll() {
    final pixels = _scrollController.position.pixels;
    final bool nextValue = pixels >= 120
        ? true
        : (pixels <= 60 ? false : _showTopButton.value);

    if (nextValue != _showTopButton.value) {
      _showTopButton.value = nextValue;
    }

    // Load more when reaching near the bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      GalleryViewModel.instance.loadMore();
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _showTopButton.dispose();
    super.dispose();
  }

  List<DailyMediaGroup> _groupMediaByDate(List<MediaAsset> mediaAssetList) {
    final Map<DateTime, List<MediaAsset>> groupedMap = {};

    for (var mediaItem in mediaAssetList) {
      final DateTime dateTime = mediaItem.createDateTime;

      // normalize to date
      final DateTime dateObj = DateTime(
        dateTime.year,
        dateTime.month,
        dateTime.day,
      );

      if (!groupedMap.containsKey(dateObj)) {
        groupedMap[dateObj] = [];
      }
      groupedMap[dateObj]!.add(mediaItem);
    }

    final List<DailyMediaGroup> groups = groupedMap.entries.map((entry) {
      return DailyMediaGroup(datetime: entry.key, mediaAssets: entry.value);
    }).toList();

    return groups;
  }

  /// Build groups of media into slivers, with trashed media filtered out
  List<Widget> _buildGroupSlivers(
    GalleryViewModel galleryVM,
    TrashViewModel trashVM,
  ) {
    final trashedAssetIds = trashVM.trashedAssetIds;
    final slivers = <Widget>[];

    // Filter out trashed media
    final filteredMediaAssets = galleryVM.mediaAssets
        .where((asset) => !trashedAssetIds.contains(asset.assetId))
        .toList();

    // Group by date
    final mediaGroups = _groupMediaByDate(filteredMediaAssets);

    if (mediaGroups.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: const Center(child: Text('No images found in gallery')),
        ),
      ];
    }

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
              assetId: mediaAsset.assetId,
              key: ValueKey(mediaAsset.assetId),
            );

            final isSelected = galleryVM.selectedAssetIds.contains(
              mediaAsset.assetId,
            );
            final selectionOverlay = GestureDetector(
              child: Container(
                color: isSelected
                    ? Colors.blue.withAlpha(100)
                    : Colors.transparent,
              ),
              onLongPress: () => GalleryViewModel.instance.toggleSelectMedia(
                mediaAsset.assetId,
              ),
              onTap: () {
                if (galleryVM.isSelectionMode) {
                  GalleryViewModel.instance.toggleSelectMedia(
                    mediaAsset.assetId,
                  );
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
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([
          GalleryViewModel.instance,
          TrashViewModel.instance,
        ]),
        builder: (context, _) {
          final galleryVM = GalleryViewModel.instance;
          final trashVM = TrashViewModel.instance;

          // Show loading spinner if initial load is in progress and no data yet
          if (galleryVM.isLoading && galleryVM.mediaAssets.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

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
                  minThumbLength: UIConfig.homeScreenScrollbarThumbMinHeight,
                  interactive: true,
                  crossAxisMargin: UIConfig.gridViewGutter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: UIConfig.gridViewGutter,
                    ),
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: _buildGroupSlivers(galleryVM, trashVM),
                      scrollDirection: Axis.vertical,
                    ),
                  ),
                ),
              ),
              // Loading indicator at the bottom during pagination
              if (galleryVM.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          );

          return Stack(
            children: [
              fullScreenImageList,
              // Scroll to top button
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
              // Debug button to move selected items to trash
              if (isDebugOrProfileMode)
                Positioned(
                  top: 40,
                  right: 20,
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: galleryVM.isSelectionMode
                            ? () => galleryVM.moveSelectedToTrash()
                            : null,
                        child: Text(
                          "Move to Trash (${galleryVM.selectedAssetIds.length})",
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: galleryVM.isSelectionMode
                            ? () => galleryVM.clearSelection()
                            : null,
                        child: const Text("Clear Selection"),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
