import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/src/common_widgets/scrollbar_no_track_tap_down.dart';
import 'package:mobile_image_search/src/common_widgets/thumbnail_widget.dart';
import 'package:mobile_image_search/src/core/constants/config_constant.dart';
import 'package:mobile_image_search/src/core/constants/route_constant.dart';
import 'package:mobile_image_search/src/feature/gallery/viewmodels/album_viewmodel.dart';
import 'package:mobile_image_search/src/feature/gallery/viewmodels/selection_viewmodel.dart';
import 'package:mobile_image_search/src/feature/gallery/viewmodels/trash_viewmodel.dart';
import 'package:mobile_image_search/src/feature/gallery/views/selection_app_bar.dart';
import 'package:mobile_image_search/src/service_locator.dart';
import 'package:mobile_image_search/src/shared/domain/model/album.dart';

class AlbumOpenedScreen extends StatefulWidget {
  const AlbumOpenedScreen({super.key, required this.currentAlbum});

  final Album currentAlbum;

  @override
  State<AlbumOpenedScreen> createState() => _AlbumOpenedScreenState();
}

class _AlbumOpenedScreenState extends State<AlbumOpenedScreen> {
  final ScrollController _scrollController = ScrollController();
  final AlbumViewModel _albumVM = ServiceLocator.albumViewModel;
  final TrashViewModel _trashVM = ServiceLocator.trashViewModel;
  final SelectionViewModel _selectionVM = ServiceLocator.selectionViewModel;

  @override
  void initState() {
    super.initState();
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
    // don't leak selection to the album list / other tabs
    _selectionVM.clear();
    debugPrint("Disposed AlbumOpenedScreen");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_albumVM, _trashVM, _selectionVM]),
      builder: (context, _) {
        return Scaffold(
          appBar: _selectionVM.isActive
              ? const SelectionAppBar()
              : AppBar(
                  title: Text(widget.currentAlbum.title),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
          body: _buildBody(),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_albumVM.isLoadingAssets && _albumVM.currentAlbumAssets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: Flex(
        direction: Axis.vertical,
        children: [
          Expanded(
            child: InteractiveThumbScrollbar(
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
    );
  }

  Widget _buildMediaGrid() {
    // Filter out trashed items and the album-cover placeholder
    final trashedAssetIds = _trashVM.trashedAssetIds;
    final filteredAssets = _albumVM.currentAlbumAssets
        .where(
          (asset) =>
              !trashedAssetIds.contains(asset.assetId) &&
              asset.title != UIConfig.albumCoverFileName,
        )
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
        final isSelected = _selectionVM.isSelected(mediaAsset);
        final thumbnailProvider = _albumVM.thumbnailProviderFor(
          mediaAsset.assetId,
        );

        final thumbnail = ThumbnailWidget(
          mediaAsset: mediaAsset,
          provider: thumbnailProvider,
        );

        final selectionOverlay = GestureDetector(
          child: Container(
            color: isSelected ? Colors.blue.withAlpha(100) : Colors.transparent,
          ),
          onLongPress: () => _selectionVM.toggle(mediaAsset),
          onTap: () {
            if (_selectionVM.isActive) {
              _selectionVM.toggle(mediaAsset);
            } else {
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
