import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/src/core/constants/route_constant.dart';
import 'package:mobile_image_search/src/feature/gallery/viewmodels/album_viewmodel.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_image_embedding.dart';
import 'package:mobile_image_search/src/feature/indexing/data/search_objectbox_model.dart';
import 'package:mobile_image_search/src/service_locator.dart';
import 'package:mobile_image_search/src/shared/domain/model/album.dart';
import 'package:mobile_image_search/src/core/utils/debug.dart';

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  final AlbumViewModel _albumVM = ServiceLocator.albumViewModel;

  @override
  void initState() {
    super.initState();
    _albumVM.loadAlbums();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showCreateAlbumDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Album'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Album Title *'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isNotEmpty) {
                  final desc = descriptionController.text.trim();
                  _albumVM.createAlbum(title, desc.isEmpty ? null : desc);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _clearObjectBoxImageEmbedding() {
    final imageBox = ServiceLocator.objectBoxService.store
        .box<ObjectBoxImageEmbedding>();
    imageBox.removeAll();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('[DEBUG] ObjectBoxImageEmbedding cleared')),
    );
    debugPrint('[DEBUG] ObjectBoxImageEmbedding cleared');
  }

  void _clearSearchQueryObjectBox() {
    final searchBox = ServiceLocator.objectBoxService.store.box<SearchQuery>();
    searchBox.removeAll();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('[DEBUG] SearchQuery cleared')),
    );
    debugPrint('[DEBUG] SearchQuery cleared');
  }

  void _clearAlbumObjectBox() {
    final albumBox = ServiceLocator.objectBoxService.store
        .box<ObjectBoxAlbum>();
    albumBox.removeAll();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('[DEBUG] ObjectBoxAlbum cleared')),
    );
    debugPrint('[DEBUG] ObjectBoxAlbum cleared');
  }

  void _confirmDeleteAlbum(Album album) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Album "${album.title}"?'),
          content: const Text(
            'This permanently deletes the photos and videos in this album. '
            'The folder is removed too if it has no other files.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _albumVM.deleteAlbum(album.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Album ${album.title} deleted')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
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
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showCreateAlbumDialog();
                      },
                      child: const Text('Create New Album'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _clearObjectBoxImageEmbedding();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      child: const Text('Clear ObjectBoxImageEmbedding'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _clearSearchQueryObjectBox();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      child: const Text('Clear SearchQuery'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _clearAlbumObjectBox();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Clear ObjectBoxAlbum'),
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
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _albumVM,
        builder: (context, _) {
          if (_albumVM.isLoadingAlbums && _albumVM.albums.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_albumVM.albums.isEmpty) {
            return const Center(child: Text("No albums found"));
          }

          return ListView.builder(
            itemCount: _albumVM.albums.length,
            itemBuilder: (context, index) {
              final Album album = _albumVM.albums[index];
              return ListTile(
                title: Text(album.title),
                // distinguish albums with the same name
                subtitle: Text(album.path ?? "ID: ${album.id}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.grey),
                  onPressed: () => _confirmDeleteAlbum(album),
                ),
                onTap: () {
                  debugPrint("Tapped on album: ${album.title}");
                  context.push(
                    RouteConstants.albumView,
                    extra: {'album': album},
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: isDebugOrProfileMode
          ? FloatingActionButton(
              onPressed: _showDebugMenu,
              tooltip: 'Debug menu',
              child: const Icon(Icons.bug_report),
            )
          : null,
    );
  }
}
