import 'package:flutter/material.dart';
import 'package:mobile_image_search/src/feature/gallery/viewmodels/selection_viewmodel.dart';
import 'package:mobile_image_search/src/service_locator.dart';

/// Top bar shown while selection is active: "N selected" + Cancel.
///
/// Hosts wrap their build in a [ListenableBuilder] on [SelectionViewModel], so
/// this is reconstructed (and the count updates) whenever the selection changes.
class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SelectionAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final SelectionViewModel selectionVM = ServiceLocator.selectionViewModel;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancel',
        onPressed: selectionVM.clear,
      ),
      title: Text('${selectionVM.count} selected'),
    );
  }
}