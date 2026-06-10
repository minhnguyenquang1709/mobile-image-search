import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/src/constants/route_constant.dart';
import 'package:mobile_image_search/src/constants/theme_constant.dart';

/// The parent container for app's main navigation structure.
///
/// Hold the bottom navigation bar and the content of the current tab (branch).
class ScaffoldWithNestedNavigation extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const ScaffoldWithNestedNavigation({
    super.key,
    required this.navigationShell,
  });

  void _showMoreOptionsMenu(BuildContext context) async {
    // get screen size
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    // define position for the menu
    final RelativeRect position = RelativeRect.fromLTRB(
      overlay.size.width - 100,
      overlay.size.height - 200,
      0,
      0,
    );

    final String? result = await showMenu(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      color: lightTheme.colorScheme.onPrimary,
      items: [
        PopupMenuItem(
          value: 'image_search',
          onTap: () {
            context.push(RouteConstants.searchByCaptionResultView);
          },
          child: Row(
            children: [
              Icon(
                Icons.image_search_rounded,
                color: lightTheme.colorScheme.primary,
                size: 30,
              ),
              Text(
                "Image Search",
                style: TextStyle(
                  color: lightTheme.colorScheme.primary,
                  fontFamily: CustomTextStyles.fontFamily,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'cleanup_suggestion',
          child: Row(
            children: [
              Icon(
                Icons.smart_toy,
                color: lightTheme.colorScheme.primary,
                size: 30,
              ),
              Text(
                "Smart Cleanup",
                style: TextStyle(
                  color: lightTheme.colorScheme.primary,
                  fontFamily: CustomTextStyles.fontFamily,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          onTap: () {
            context.push(RouteConstants.settings);
          },
          child: Row(
            children: [
              Icon(Icons.settings, color: CustomColors.textPrimary, size: 30),
              Text(
                "Settings",
                style: TextStyle(
                  color: lightTheme.colorScheme.primary,
                  fontFamily: CustomTextStyles.fontFamily,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // void _goBranch(int index) {
  //   debugPrint("Navigating to branch $index");
  //   if (index == 2) {
  //     return;
  //   }
  //   navigationShell.goBranch(
  //     index == 3 ? 2 : index,
  //     // A common pattern when using bottom navigation bars is to support
  //     // navigating to the initial location when tapping the item that is
  //     // already active. This example demonstrates how to support this behavior,
  //     // using the initialLocation parameter of goBranch.
  //     initialLocation: index == navigationShell.currentIndex,
  //   );
  // }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      // appBar: (navigationShell.currentIndex == 0 && selectedAssetIds.isNotEmpty)
      //     ? AppBar(
      //         title: Row(
      //           children: [
      //             IconButton(
      //               icon: Icon(Icons.arrow_back),
      //               color: lightTheme.colorScheme.primary,
      //               // style: ButtonStyle(
      //               //   backgroundColor: MaterialStateProperty.all(
      //               //     lightTheme.colorScheme.error,
      //               //   ),
      //               // ),
      //               onPressed: () {
      //                 ref
      //                     .read(homeScreenSelectionControllerProvider.notifier)
      //                     .clearSelection();
      //               },
      //             ),
      //             Text("${selectedAssetIds.length} selected"),
      //           ],
      //         ),
      //         titleTextStyle: TextStyle(
      //           fontFamily: CustomTextStyles.fontFamily,
      //           color: lightTheme.colorScheme.onSurfaceVariant,
      //           fontSize: 20,
      //           fontWeight: FontWeight.w400,
      //         ),
      //         toolbarHeight: 50,
      //         backgroundColor: lightTheme.colorScheme.surface,
      //         titleSpacing: 0,
      //         surfaceTintColor: Colors.transparent,
      //       )
      //     : null,
      body: SafeArea(child: navigationShell),
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.photo_album), label: 'Albums'),
          NavigationDestination(icon: Icon(Icons.delete), label: 'Trash'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        onDestinationSelected: (int index) {
          // handle StatefulShellBranch's index

          navigationShell.goBranch(
            index,
            // tap on current tab should navigate to initial location of the branch
            // initialLocation: index == navigationShell.currentIndex,
          );
        },
        selectedIndex: navigationShell.currentIndex,
      ),
    );
  }
}
