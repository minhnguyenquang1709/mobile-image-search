import 'package:flutter/material.dart';
import 'package:mobile_image_search/src/feature/gallery/viewmodels/album_viewmodel.dart';
import 'package:mobile_image_search/src/feature/gallery/viewmodels/selection_viewmodel.dart';
import 'package:mobile_image_search/src/feature/gallery/viewmodels/trash_viewmodel.dart';
import 'package:mobile_image_search/src/feature/gallery/views/album_picker_sheet.dart';
import 'package:mobile_image_search/src/service_locator.dart';
import 'package:mobile_image_search/src/shared/domain/model/album.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

/// Bottom action bar shown while selection is active: Move to Album / Trash / Clear.
class SelectionActionBar extends StatelessWidget {
  const SelectionActionBar({super.key});

  Future<void> _moveToAlbum(BuildContext context) async {
    final SelectionViewModel selectionVM = ServiceLocator.selectionViewModel;
    final AlbumViewModel albumVM = ServiceLocator.albumViewModel;

    final List<MediaAsset> assets = selectionVM.selected.toList();
    if (assets.isEmpty) return;

    final Album? album = await showAlbumPickerSheet(context, albumVM);
    if (album == null) return;

    selectionVM.clear();
    try {
      await albumVM.moveAssetsToAlbum(album, assets);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error moving to album: $e')));
      }
    }
  }

  Future<void> _moveToTrash(BuildContext context) async {
    final SelectionViewModel selectionVM = ServiceLocator.selectionViewModel;
    final TrashViewModel trashVM = ServiceLocator.trashViewModel;

    final List<MediaAsset> assets = selectionVM.selected.toList();
    if (assets.isEmpty) return;

    selectionVM.clear();
    try {
      await trashVM.moveToTrash(assets);
      if (context.mounted) {
        final List<String> ids = assets.map((a) => a.assetId).toList();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved ${assets.length} to trash'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => trashVM.restoreTrashedMedia(ids),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error moving to trash: $e')));
      }
    }
  }

  Widget _buildAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SelectionViewModel selectionVM = ServiceLocator.selectionViewModel;
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildAction(
            Icons.drive_file_move_outline,
            'Album',
            () => _moveToAlbum(context),
          ),
          _buildAction(
            Icons.delete_outline,
            'Trash',
            () => _moveToTrash(context),
          ),
          _buildAction(Icons.close, 'Clear', selectionVM.clear),
        ],
      ),
    );
  }
}