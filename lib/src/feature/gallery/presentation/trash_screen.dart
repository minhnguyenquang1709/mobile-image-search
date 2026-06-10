import 'package:flutter/material.dart';
import 'package:mobile_image_search/src/common_widgets/thumbnail_widget.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/trash_view_model.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  late TrashViewModel _trashVM;
  final Set<String> _selectedAssetIds = {};
  bool get isInSelectionMode => _selectedAssetIds.isNotEmpty;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _trashVM = TrashViewModel.instance;
    _trashVM.addListener(_refresh);
    _loadTrashEntries();
  }

  void _refresh() {
    setState(() {});
    debugPrint("[TrashScreen] Refreshing UI...");
  }

  Future<void> _loadTrashEntries() async {
    debugPrint("[TrashScreen] Loading trash entries...");
    try {
      await _trashVM.loadFromDatabase();
      debugPrint(
        "[TrashScreen] Trash entries loaded: ${_trashVM.trashedAssetIds.length}",
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading trash: $e')));
      }
    }
  }

  void _toggleSelect(String assetId) {
    setState(() {
      if (_selectedAssetIds.contains(assetId)) {
        _selectedAssetIds.remove(assetId);
      } else {
        _selectedAssetIds.add(assetId);
      }
    });
  }

  Future<void> _restoreSelected() async {
    if (_selectedAssetIds.isEmpty) return;
    debugPrint("[TrashScreen] Restoring ${_selectedAssetIds.length} items");
    try {
      await _trashVM.restoreTrashedMedia(_selectedAssetIds.toList());
      setState(() => _selectedAssetIds.clear());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error restoring: $e')));
      }
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedAssetIds.isEmpty) return;
    debugPrint(
      "[TrashScreen] Permanently deleting ${_selectedAssetIds.length} items",
    );
    try {
      await _trashVM.permanentlyDelete(_selectedAssetIds.toList());
      setState(() => _selectedAssetIds.clear());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _trashVM.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          if (isInSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: 'Restore',
              onPressed: _restoreSelected,
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Delete permanently',
              onPressed: _deleteSelected,
            ),
          ],

          if (_trashVM.trashedAssetIds.isNotEmpty && !isInSelectionMode)
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Select all',
              onPressed: () {
                setState(() {
                  _selectedAssetIds.addAll(_trashVM.trashedAssetIds);
                });
              },
            ),

          // Empty trash bin
          if (_trashVM.trashedAssetIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Empty Trash',
              onPressed: () async {
                await _trashVM.permanentlyDelete(
                  _trashVM.trashedAssetIds.toList(),
                );
              },
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _trashVM,
        builder: (context, _) {
          final trashedIds = _trashVM.trashedAssetIds;

          if (trashedIds.isEmpty) {
            return const Center(child: Text('Trash is empty'));
          }

          return SafeArea(
            child: RawScrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 2,
                            crossAxisSpacing: 2,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final assetId = trashedIds.elementAt(index);
                        final isSelected = _selectedAssetIds.contains(assetId);

                        final thumbnail = ThumbnailWidget(
                          assetId: assetId,
                          key: ValueKey(assetId),
                        );

                        final selectionOverlay = GestureDetector(
                          child: Container(
                            color: isSelected
                                ? Colors.blue.withAlpha(100)
                                : Colors.transparent,
                          ),
                          onLongPress: () => _toggleSelect(assetId),
                          onTap: () {
                            if (isInSelectionMode)
                              _toggleSelect(assetId);
                            else {
                              // context.push(
                              //   RouteConstants.mediaView,
                              //   extra: {'assetId': assetId},
                              // );
                            }
                          },
                        );

                        return Stack(children: [thumbnail, selectionOverlay]);
                      }, childCount: trashedIds.length),
                    ),
                  ],
                  scrollDirection: Axis.vertical,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
