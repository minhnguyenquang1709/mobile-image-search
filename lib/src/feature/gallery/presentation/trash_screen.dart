import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/common_widgets/thumbnail_widget.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/trash_controller.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trashAsync = ref.watch(trashControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: () {
              ref.read(trashControllerProvider.notifier).restoreSelected();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              ref
                  .read(trashControllerProvider.notifier)
                  .deleteSelectedPermanently();
            },
          ),
        ],
      ),
      body: trashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (state) {
          if (state.items.isEmpty) {
            return const Center(child: Text('No assets in trash'));
          }

          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final item = state.items[index];
              final isSelected = state.selectedAssetIds.contains(
                item.asset.assetId,
              );

              return Stack(
                children: [
                  ThumbnailWidget(
                    mediaAsset: item.asset,
                    onTap: (_) {
                      ref
                          .read(trashControllerProvider.notifier)
                          .toggleSelect(item.asset.assetId);
                    },
                  ),
                  if (isSelected) Container(color: Colors.blue.withAlpha(100)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
