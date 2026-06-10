import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/src/common_widgets/thumbnail_widget.dart';
import 'package:mobile_image_search/src/constants/config_constant.dart';
import 'package:mobile_image_search/src/constants/route_constant.dart';
import 'package:mobile_image_search/src/constants/theme_constant.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/gallery_view_model.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/trash_view_model.dart';
import 'package:mobile_image_search/src/service_locator.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

class MainGalleryScreen extends StatefulWidget {
  const MainGalleryScreen({super.key});

  @override
  State<MainGalleryScreen> createState() => _MainGalleryScreenState();
}

class _MainGalleryScreenState extends State<MainGalleryScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _showTopButton = ValueNotifier(false);
  final ValueNotifier<bool> _showSearchBar = ValueNotifier(false);
  final TextEditingController _searchTextController = TextEditingController();
  double _lastOffset = 0.0;

  final GalleryViewModel _galleryVM = GalleryViewModel.instance;
  final TrashViewModel _trashVM = TrashViewModel.instance;

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

    // Show search bar on scroll down, hide on scroll up
    if (pixels > _lastOffset && pixels > 50) {
      if (!_showSearchBar.value) {
        _showSearchBar.value = true;
      }
    } else if (pixels < _lastOffset || pixels <= 50) {
      if (_showSearchBar.value) {
        _showSearchBar.value = false;
      }
    }
    _lastOffset = pixels;

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

  void _performSearchByPhrase(String query) {
    debugPrint("[MainGalleryScreen] Performing search for: $query");
    _galleryVM.searchByPhrase(query);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _showTopButton.dispose();
    _showSearchBar.dispose();
    _searchTextController.dispose();
    super.dispose();
  }

  void _showDebugMenu(GalleryViewModel galleryVM) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Debug Menu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select an action:'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: galleryVM.isSelectionMode
                          ? () {
                              Navigator.of(context).pop();
                              galleryVM.moveSelectedToTrash();
                            }
                          : null,
                      child: Text(
                        "Move to Trash (${galleryVM.selectedAssetIds.length})",
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: galleryVM.isSelectionMode
                          ? () {
                              Navigator.of(context).pop();
                              galleryVM.clearSelection();
                            }
                          : null,
                      child: const Text("Clear Selection"),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                await ServiceLocator.indexingService.indexGallery();
              },
              child: const Text('Start indexing'),
            ),
          ],
        );
      },
    );
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
    List<MediaAsset> mediaAssetsToDisplay,
    Set<String> filteredOutAssetIds,
    Set<String> selectedAssetIds,
    bool isSelectionMode,
  ) {
    final slivers = <Widget>[];

    // Filter out trashed media
    List<MediaAsset> filteredMediaAssets = mediaAssetsToDisplay
        .where((asset) => !filteredOutAssetIds.contains(asset.assetId))
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

            final isSelected = selectedAssetIds.contains(mediaAsset.assetId);
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
                if (isSelectionMode) {
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
        listenable: Listenable.merge([_galleryVM, _trashVM]),
        builder: (context, _) {
          // Show loading spinner if initial load is in progress and no data yet
          if (_galleryVM.isLoading && _galleryVM.mediaAssets.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final bool isSearchModeOn = _galleryVM.isSearchModeOn;

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
                      slivers: isSearchModeOn
                          ? _buildGroupSlivers(
                              _galleryVM.searchResults,
                              _trashVM.trashedAssetIds,
                              _galleryVM.selectedAssetIds,
                              _galleryVM.isSelectionMode,
                            )
                          : _buildGroupSlivers(
                              _galleryVM.mediaAssets,
                              _trashVM.trashedAssetIds,
                              _galleryVM.selectedAssetIds,
                              _galleryVM.isSelectionMode,
                            ),
                      scrollDirection: Axis.vertical,
                    ),
                  ),
                ),
              ),
              // Loading indicator at the bottom during pagination
              if (_galleryVM.isLoading)
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
              // debug button
              ValueListenableBuilder<bool>(
                valueListenable: _showSearchBar,
                builder: (context, searchVisible, _) {
                  return AnimatedPositioned(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOutCubic,
                    bottom: searchVisible ? 88 : 16,
                    left: 16,
                    child: FloatingActionButton(
                      onPressed: () => _showDebugMenu(_galleryVM),
                      tooltip: 'Debug Menu',
                      child: const Icon(Icons.bug_report),
                    ),
                  );
                },
              ),
              // Search input bar
              ValueListenableBuilder<bool>(
                valueListenable: _showSearchBar,
                builder: (context, visible, child) {
                  return AnimatedPositioned(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOutCubic,
                    bottom: visible ? 16 : -80,
                    left: 16,
                    right: 80,
                    child: child!,
                  );
                },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(38),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(Icons.search, color: Colors.grey),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchTextController,
                          decoration: const InputDecoration(
                            hintText: "Search with an English phrase",
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                          onSubmitted: _performSearchByPhrase,
                          onChanged: (value) {
                            // Optionally handle on change
                          },
                        ),
                      ),
                      if (isSearchModeOn)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchTextController.clear();
                            _galleryVM.clearSearch();
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _performSearchByPhrase(_searchTextController.text);
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: ValueListenableBuilder(
        valueListenable: _showTopButton,
        builder: (context, visible, _) {
          return IgnorePointer(
            ignoring: !visible,
            child: Opacity(
              opacity: visible ? 1 : 0,
              child: FloatingActionButton(
                onPressed: _scrollToTop,
                tooltip: 'Scroll to top',
                child: const Icon(Icons.arrow_upward),
              ),
            ),
          );
        },
      ),
    );
  }
}
