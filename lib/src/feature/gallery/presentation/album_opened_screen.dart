import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/src/common_widgets/thumbnail_widget.dart';
import 'package:mobile_image_search/src/constants/config_constant.dart';
import 'package:mobile_image_search/src/constants/route_constant.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/album_view_model.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/trash_view_model.dart';
import 'package:mobile_image_search/src/shared/domain/model/album.dart';
import 'package:mobile_image_search/src/utils/debug.dart';

class AlbumOpenedScreen extends StatefulWidget {
  const AlbumOpenedScreen({super.key, required this.currentAlbum});

  final Album currentAlbum;

  @override
  State<AlbumOpenedScreen> createState() => _AlbumOpenedScreenState();
}

class _AlbumOpenedScreenState extends State<AlbumOpenedScreen> {
  final ScrollController _scrollController = ScrollController();
  final AlbumViewModel _albumVM = AlbumViewModel.instance;
  final TrashViewModel _trashVM = TrashViewModel.instance;

  @override
  void initState() {
    super.initState();
    _albumVM.clearSelection();
    _albumVM.loadAlbumDetailsInitial(widget.currentAlbum.id);

    // infinite scroll
    _scrollController.addListener(() {
      if ((_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200) &&
          !_albumVM.isLoadingAssets) {
        debugPrint(
          "[AlbumOpenedScreen] Reached near the bottom of the album media list, loading more...",
        );
        _albumVM.loadAlbumDetailsNextPage();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    debugPrint("Disposed AlbumOpenedScreen");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.currentAlbum.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _albumVM.clearSelection();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_albumVM, _trashVM]),
        builder: (context, _) {
          if (_albumVM.isLoadingAssets && _albumVM.currentAlbumAssets.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            children: [
              SafeArea(
                child: Flex(
                  direction: Axis.vertical,
                  children: [
                    Expanded(
                      child: RawScrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: CustomScrollView(
                            controller: _scrollController,
                            slivers: [_buildMediaGrid()],
                            scrollDirection: Axis.vertical,
                          ),
                        ),
                      ),
                    ),
                    if (_albumVM.isLoadingAssets &&
                        _albumVM.currentAlbumAssets.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
              // debugging button to move selected items to trash
              if (isDebugOrProfileMode)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Column(
                    children: [
                      Text("${_albumVM.currentAlbumAssets.length} items"),
                      ElevatedButton(
                        onPressed: _albumVM.isSelectionMode
                            ? () => _albumVM.moveSelectedToTrash()
                            : null,
                        child: Text(
                          "Move to Trash (${_albumVM.selectedAssetIds.length})",
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _albumVM.isSelectionMode
                            ? () => _albumVM.clearSelection()
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

  Widget _buildMediaGrid() {
    // Filter out trashed items
    final trashedAssetIds = _trashVM.trashedAssetIds;
    final filteredAssets = _albumVM.currentAlbumAssets
        .where((asset) => !trashedAssetIds.contains(asset.assetId))
        .toList();

    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: UIConfig.thumbnailsPerRow,
        mainAxisSpacing: UIConfig.gridMainAxisSpacing,
        crossAxisSpacing: UIConfig.gridCrossAxisSpacing,
      ),
      itemCount: filteredAssets.length,
      itemBuilder: (context, index) {
        final mediaAsset = filteredAssets[index];
        final isSelected = _albumVM.selectedAssetIds.contains(
          mediaAsset.assetId,
        );

        final thumbnail = ThumbnailWidget(assetId: mediaAsset.assetId);

        final selectionOverlay = GestureDetector(
          child: Container(
            color: isSelected ? Colors.blue.withAlpha(100) : Colors.transparent,
          ),
          onLongPress: () {
            debugPrint(
              "Long pressed thumbnail with assetId: ${mediaAsset.assetId}",
            );
            _albumVM.toggleSelectMedia(mediaAsset.assetId);
          },
          onTap: () {
            if (_albumVM.isSelectionMode) {
              debugPrint(
                "[AlbumOpenedScreen] Tapped thumbnail in selection mode with assetId: ${mediaAsset.assetId}",
              );
              _albumVM.toggleSelectMedia(mediaAsset.assetId);
            } else {
              debugPrint(
                "[AlbumOpenedScreen] Tapped thumbnail in normal mode with assetId: ${mediaAsset.assetId}",
              );
              context.push(
                RouteConstants.mediaView,
                extra: {'media': mediaAsset},
              );
            }
          },
        );

        return Stack(children: [thumbnail, selectionOverlay]);
      },
    );
  }
}
