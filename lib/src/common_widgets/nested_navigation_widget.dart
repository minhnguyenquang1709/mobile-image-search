import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/src/feature/gallery/views/selection_action_bar.dart';
import 'package:mobile_image_search/src/service_locator.dart';

/// The parent container for app's main navigation structure.
///
/// Hold the bottom navigation bar and the content of the current tab (branch).
class ScaffoldWithNestedNavigation extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const ScaffoldWithNestedNavigation({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: navigationShell),
      // In selection mode the bottom bar morphs into action buttons (Samsung-style).
      bottomNavigationBar: ListenableBuilder(
        listenable: ServiceLocator.selectionViewModel,
        builder: (context, _) {
          final bool isSelecting = ServiceLocator.selectionViewModel.isActive;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isSelecting
                ? const SelectionActionBar(key: ValueKey('selectionActionBar'))
                : _buildNavigationBar(),
          );
        },
      ),
    );
  }

  Widget _buildNavigationBar() {
    return NavigationBar(
      key: const ValueKey('navigationBar'),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.photo_album), label: 'Albums'),
        NavigationDestination(icon: Icon(Icons.delete), label: 'Trash'),
        NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
      ],
      onDestinationSelected: (int index) {
        // clear any stale selection when switching tabs
        ServiceLocator.selectionViewModel.clear();
        navigationShell.goBranch(index);
      },
      selectedIndex: navigationShell.currentIndex,
    );
  }
}