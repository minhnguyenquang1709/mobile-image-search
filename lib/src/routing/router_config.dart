import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/src/common_widgets/settings_screen.dart';
import 'package:mobile_image_search/src/constants/route_constant.dart';
import 'package:mobile_image_search/src/common_widgets/nested_navigation_widget.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/home_screen.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/full_media_view_screen.dart';
import 'package:mobile_image_search/src/feature/search/presentation/image_search_screen.dart';
import 'package:mobile_image_search/src/shared/domain/model/media.dart';

// GlobalKey: unique identifier, provide access to `BuildContext`, `State`, `Widget`
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorHomeKey = GlobalKey<NavigatorState>();
final _shellNavigatorAlbumsKey = GlobalKey<NavigatorState>();

final topLevelNavigationRouter = GoRouter(
  initialLocation: RouteConstants.home,
  navigatorKey: _rootNavigatorKey,
  routes: [
    StatefulShellRoute.indexedStack(
      builder:
          (
            BuildContext context,
            GoRouterState state,
            StatefulNavigationShell navigationShell,
          ) {
            // the UI shell that holds the navigation branches (tabs) and the content of the current branch
            // return ScaffoldWithNestedNavigation(navigationShell: navigationShell);
            return ScaffoldWithNestedNavigation(
              navigationShell: navigationShell,
            );
          },
      branches: [
        // top-level branch (aka tabs in app navigation bar)
        StatefulShellBranch(
          navigatorKey: _shellNavigatorHomeKey,
          routes: [
            // the GoRoutes at this level will be rendered inside ScaffoldWithNestedNavigation
            // root screen
            GoRoute(
              path: RouteConstants.home,
              builder: (BuildContext context, GoRouterState state) =>
                  HomeScreen(),
              // routes: [
              //   // child route
              //   GoRoute(
              //     path: RouteConstants.albums,
              //     builder: (context, state) {
              //       return HomeScreen();
              //     },
              //   ),
              // ],
            ),
          ],
        ),
        // 2nd top-level branch
        StatefulShellBranch(
          navigatorKey: _shellNavigatorAlbumsKey,
          routes: [
            GoRoute(
              path: RouteConstants.albums,
              builder: (context, state) {
                return Container();
              },
            ),
          ],
        ),
      ],
    ),
    // route outside of shell, full screen dialog
    // full media viewer
    GoRoute(
      path: RouteConstants.mediaViewer,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final image = extra?['image'] as Media;
        return MediaViewScreen(media: image);
      },
    ),

    // settings screen
    GoRoute(
      path: RouteConstants.settings,
      builder: (context, state) {
        return SettingsScreen();
      },
    ),

    // search by caption screen
    GoRoute(
      path: RouteConstants.searchByCaption,
      builder: (context, state) {
        return ImageSearchScreen();
      },
    ),
  ],
);
