import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/common_widgets/thumbnail_widget.dart';
import 'package:mobile_image_search/src/constants/config_constant.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/album_controller.dart';
import 'package:mobile_image_search/src/shared/domain/model/album.dart';

class AlbumOpenedScreen extends ConsumerStatefulWidget {
  const AlbumOpenedScreen({super.key, required this.currentAlbum});

  final Album currentAlbum;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _AlbumOpenedScreenState();
}

class _AlbumOpenedScreenState extends ConsumerState<AlbumOpenedScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    ref
        .read(albumDetailControllerProvider(widget.currentAlbum.id).notifier)
        .clearSelection();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    debugPrint("Disposed AlbumOpenedScreen");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      albumDetailControllerProvider(widget.currentAlbum.id),
    );

    return Scaffold(
      body: Container(
        child: switch (state) {
          AsyncLoading() => const Center(child: CircularProgressIndicator()),
          AsyncError(:final error) => Center(child: Text('Error: $error')),
          AsyncData(:final value) => _buildMediaGrid(value),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  Widget _buildMediaGrid(AlbumDetailState state) {
    final SliverGrid mediaGrid = SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: UIConfig.thumbnailsPerRow,
        mainAxisSpacing: UIConfig.gridMainAxisSpacing,
        crossAxisSpacing: UIConfig.gridCrossAxisSpacing,
      ),
      itemCount: state.mediaAssets.length,
      itemBuilder: (context, index) {
        // selection overlay
        final mediaAsset = state.mediaAssets[index];
        final isSelected = state.selectedAssetIds.contains(mediaAsset.assetId);

        final thumbnail = ThumbnailWidget(
          mediaAsset: mediaAsset,
          onLongPress: () {
            debugPrint(
              "Long pressed thumbnail with assetId: ${mediaAsset.assetId}",
            );
            debugPrint(
              "Selection status: ${state.selectedAssetIds.contains(mediaAsset.assetId)}",
            );
            ref
                .read(
                  albumDetailControllerProvider(
                    widget.currentAlbum.id,
                  ).notifier,
                )
                .toggleSelectMedia(mediaAsset.assetId);
          },
        );
        final selectionOverlay = IgnorePointer(
          child: Container(
            color: isSelected
                ? Colors.blue.withAlpha(100)
                : Colors.transparent, // semi-transparent blue if selected
          ),
        );

        final Stack stack = Stack(children: [thumbnail, selectionOverlay]);

        // show thumbnail
        return stack;
      },
    );
    return Flex(
      direction: Axis.vertical,
      children: [
        Expanded(
          child: RawScrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [mediaGrid],
                scrollDirection: Axis.vertical,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
