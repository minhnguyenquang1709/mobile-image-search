import 'package:flutter/material.dart';
import 'package:mobile_image_search/src/feature/gallery/viewmodels/album_viewmodel.dart';
import 'package:mobile_image_search/src/shared/domain/model/album.dart';

/// Bottom sheet that lets the user pick an existing album (or create a new one)
/// to move media into. Returns the chosen [Album], or null if dismissed.
Future<Album?> showAlbumPickerSheet(
  BuildContext context,
  AlbumViewModel albumVM,
) {
  // make sure the list is populated
  albumVM.loadAlbums();

  return showModalBottomSheet<Album>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: ListenableBuilder(
          listenable: albumVM,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Move to album',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Create new album'),
                  onTap: () async {
                    final Album? created = await _promptNewAlbum(
                      context,
                      albumVM,
                    );
                    if (created != null && context.mounted) {
                      Navigator.of(context).pop(created);
                    }
                  },
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: albumVM.albums.length,
                    itemBuilder: (context, index) {
                      final Album album = albumVM.albums[index];
                      return ListTile(
                        leading: const Icon(Icons.photo_album),
                        title: Text(album.title),
                        onTap: () => Navigator.of(context).pop(album),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

/// Prompt for a new album name, create it, and return it (title is enough for
/// the move - native builds the folder path from the name).
Future<Album?> _promptNewAlbum(BuildContext context, AlbumViewModel albumVM) {
  final TextEditingController titleController = TextEditingController();

  return showDialog<Album>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Create New Album'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Album Title *'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              final Album createdAlbum = await albumVM.createAlbum(title);
              if (context.mounted) {
                Navigator.of(context).pop(createdAlbum);
              }
            },
            child: const Text('Create'),
          ),
        ],
      );
    },
  );
}
