import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/src/common_widgets/thumbnail_widget.dart';
import 'package:mobile_image_search/src/core/constants/config_constant.dart';
import 'package:mobile_image_search/src/core/constants/route_constant.dart';
import 'package:mobile_image_search/src/feature/gallery/viewmodels/trash_viewmodel.dart';
import 'package:mobile_image_search/src/feature/search/viewmodels/image_search_viewmodel.dart';
import 'package:mobile_image_search/src/service_locator.dart';

/// Grid of semantic search results. Shown by [MainGalleryScreen] while a search
/// is active.
class SearchGridView extends StatefulWidget {
  const SearchGridView({super.key});

  @override
  State<SearchGridView> createState() => _SearchGridViewState();
}

class _SearchGridViewState extends State<SearchGridView> {
  final SearchViewModel _searchViewModel = ServiceLocator.searchViewModel;
  final TrashViewModel _trashVM = ServiceLocator.trashViewModel;
  final ScrollController _scrollController = ScrollController();

  // Selection is UI logic, so it lives in the view's state, not the viewmodel.
  final Set<String> _selectedAssetIds = {};
  bool get _isSelectionMode => _selectedAssetIds.isNotEmpty;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
    final selectedMediaAssets = _searchViewModel.searchResults
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_searchViewModel, _trashVM]),
      builder: (context, _) {
        // loading
        if (_searchViewModel.isSearching) {
          return const Center(child: CircularProgressIndicator());
        }

        // error
        if (_searchViewModel.errorMessage.isNotEmpty) {
          return Center(child: Text(_searchViewModel.errorMessage));
        }

        // filter out trashed results
        final results = _searchViewModel.searchResults
            .where((a) => !_trashVM.trashedAssetIds.contains(a.assetId))
            .toList();

        // empty
        if (results.isEmpty) {
          return const Center(child: Text('No results'));
        }

        final grid = GridView.builder(
          controller: _scrollController,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: UIConfig.thumbnailsPerRow,
            crossAxisSpacing: UIConfig.gridCrossAxisSpacing,
            mainAxisSpacing: UIConfig.gridMainAxisSpacing,
          ),
          itemCount: results.length,
          itemBuilder: (context, idx) {
            final mediaAsset = results[idx];
            final thumbnailProvider = _searchViewModel.thumbnailProviderFor(
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

            return Stack(children: [thumbnail, selectionOverlay]);
          },
        );

        return Stack(
          children: [
            grid,
            // selection action bar
            if (_isSelectionMode)
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _moveSelectedToTrash,
                      icon: const Icon(Icons.delete_outline),
                      label: Text("Move to Trash (${_selectedAssetIds.length})"),
                    ),
                    ElevatedButton(
                      onPressed: _clearSelection,
                      child: const Text("Clear"),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
