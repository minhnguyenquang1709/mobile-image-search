import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/src/common_widgets/thumbnail_widget.dart';
import 'package:mobile_image_search/src/core/constants/config_constant.dart';
import 'package:mobile_image_search/src/core/constants/route_constant.dart';
import 'package:mobile_image_search/src/core/constants/theme_constant.dart';
import 'package:mobile_image_search/src/core/utils/debug.dart';
import 'package:mobile_image_search/src/feature/gallery/viewmodels/album_viewmodel.dart';
import 'package:mobile_image_search/src/feature/gallery/viewmodels/gallery_viewmodel.dart';
import 'package:mobile_image_search/src/feature/gallery/viewmodels/trash_viewmodel.dart';
import 'package:mobile_image_search/src/feature/gallery/views/album_picker_sheet.dart';
import 'package:mobile_image_search/src/service_locator.dart';
import 'package:mobile_image_search/src/shared/domain/model/album.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:mobile_image_search/src/shared/domain/model/move_progress.dart';

/// The date-grouped grid of device media
class GalleryView extends StatefulWidget {
  const GalleryView({super.key});

  @override
  State<GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _showTopButton = ValueNotifier(false);

  final GalleryViewModel _galleryVM = ServiceLocator.galleryViewModel;
  final TrashViewModel _trashVM = ServiceLocator.trashViewModel;
  final AlbumViewModel _albumVM = ServiceLocator.albumViewModel;

  // Selection is UI logic, so it lives in the view's state, not the viewmodel.
  final Set<String> _selectedAssetIds = {};
  bool get _isSelectionMode => _selectedAssetIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadGalleryData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _showTopButton.dispose();
    super.dispose();
  }

  Future<void> _loadGalleryData() async {
    try {
      await _galleryVM.loadInitial();
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
      _galleryVM.loadMore();
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // Selection
  void _toggleSelectMedia(String assetId) {
    setState(() {
      if (_selectedAssetIds.contains(assetId)) {
        _selectedAssetIds.remove(assetId);
      } else {
        _selectedAssetIds.add(assetId);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedAssetIds.clear());
  }

  Future<void> _moveSelectedToTrash() async {
    if (_selectedAssetIds.isEmpty) return;

    // find the full MediaAsset objects for selected IDs
    final selectedMediaAssets = _galleryVM.mediaAssets
        .where((a) => _selectedAssetIds.contains(a.assetId))
        .toList();
    if (selectedMediaAssets.isEmpty) return;

    // The move-to-trash operation lives in TrashViewModel.
    try {
      await _trashVM.moveToTrash(selectedMediaAssets);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error moving to trash: $e')));
      }
    }
    _clearSelection();
  }

  Future<void> _moveSelectedToAlbum() async {
    if (_selectedAssetIds.isEmpty) return;

    // find the full MediaAsset objects for selected IDs
    final selectedMediaAssets = _galleryVM.mediaAssets
        .where((a) => _selectedAssetIds.contains(a.assetId))
        .toList();
    if (selectedMediaAssets.isEmpty) return;

    // let the user pick (or create) the destination album
    final Album? album = await showAlbumPickerSheet(context, _albumVM);
    if (album == null) return;

    try {
      await _albumVM.moveAssetsToAlbum(album, selectedMediaAssets);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error moving to album: $e')));
      }
    }
    // old ids are now stale (copies got new ids); just clear the selection.
    _clearSelection();
  }

  void _showDebugMenu() {
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
                      onPressed: _isSelectionMode
                          ? () {
                              Navigator.of(context).pop();
                              _moveSelectedToTrash();
                            }
                          : null,
                      child: Text(
                        "Move to Trash (${_selectedAssetIds.length})",
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isSelectionMode
                          ? () {
                              Navigator.of(context).pop();
                              _moveSelectedToAlbum();
                            }
                          : null,
                      child: Text(
                        "Move to Album (${_selectedAssetIds.length})",
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isSelectionMode
                          ? () {
                              Navigator.of(context).pop();
                              _clearSelection();
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
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push(RouteConstants.evaluation);
              },
              child: const Text('Run model evaluation'),
            ),
          ],
        );
      },
    );
  }

  /// A small banner showing "move to album" progress, mirroring IndexingCard.
  Widget _buildMoveBanner() {
    final MoveProgress p = _albumVM.moveProgress;
    if (p.state == MoveState.idle) return const SizedBox.shrink();

    final String label;
    switch (p.state) {
      case MoveState.copying:
        label = "Moving to album ${p.processed} / ${p.total}";
        break;
      case MoveState.awaitingConsent:
        label = "Confirm deleting originals…";
        break;
      case MoveState.done:
        label = "Moved to album";
        break;
      case MoveState.denied:
        label = "Move cancelled";
        break;
      case MoveState.error:
        label = "Move failed";
        break;
      case MoveState.idle:
        label = "";
        break;
    }

    return Card(
      child: ListTile(
        title: const Text("Move to album"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            LinearProgressIndicator(
              color: CustomColors.primary,
              backgroundColor: CustomColors.divider,
              value: p.total == 0 ? null : p.processed / p.total,
            ),
          ],
        ),
      ),
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
            final thumbnailProvider = _galleryVM.thumbnailProviderFor(
              mediaAsset.assetId,
            );

            final thumbnail = ThumbnailWidget(
              mediaAsset: mediaAsset,
              provider: thumbnailProvider,
              key: ValueKey(mediaAsset.assetId),
            );

            final isSelected = _selectedAssetIds.contains(mediaAsset.assetId);
            final selectionOverlay = GestureDetector(
              child: Container(
                color: isSelected
                    ? Colors.blue.withAlpha(100)
                    : Colors.transparent,
              ),
              onLongPress: () => _toggleSelectMedia(mediaAsset.assetId),
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelectMedia(mediaAsset.assetId);
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
    return ListenableBuilder(
      listenable: Listenable.merge([_galleryVM, _trashVM, _albumVM]),
      builder: (context, _) {
        // Show loading spinner if initial load is in progress and no data yet
        if (_galleryVM.isLoading && _galleryVM.mediaAssets.isEmpty) {
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
                interactive: false,
                crossAxisMargin: UIConfig.gridViewGutter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UIConfig.gridViewGutter,
                  ),
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: _buildGroupSlivers(
                      _galleryVM.mediaAssets,
                      _trashVM.trashedAssetIds,
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
            // move-to-album progress banner
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: _buildMoveBanner(),
            ),
            // debug button
            if (isDebugOrProfileMode)
              Positioned(
                bottom: 88,
                left: 16,
                child: FloatingActionButton(
                  heroTag: 'galleryDebugFab',
                  onPressed: _showDebugMenu,
                  tooltip: 'Debug Menu',
                  child: const Icon(Icons.bug_report),
                ),
              ),
            // scroll-to-top button
            ValueListenableBuilder<bool>(
              valueListenable: _showTopButton,
              builder: (context, visible, _) {
                return Positioned(
                  bottom: 88,
                  right: 16,
                  child: IgnorePointer(
                    ignoring: !visible,
                    child: Opacity(
                      opacity: visible ? 1 : 0,
                      child: FloatingActionButton(
                        heroTag: 'galleryScrollTopFab',
                        onPressed: _scrollToTop,
                        tooltip: 'Scroll to top',
                        child: const Icon(Icons.arrow_upward),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
