import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/core/constants/route_constant.dart';
import 'package:mobile_image_search/core/presentation/nested_navigation_widget.dart';
import 'package:mobile_image_search/feature/gallery/presentation/home_screen.dart';
import 'package:mobile_image_search/feature/gallery/presentation/full_image_view_screen.dart';
import 'package:mobile_image_search/shared/domain/media.dart';

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
    // GoRoute(
    //   path: RouteConstants.home,
    //   builder: (context, state) => HomeScreen(),
    // ),
    GoRoute(
      path: RouteConstants.imageViewer,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final image = extra?['image'] as Media;
        return MediaViewScreen(media: image);
      },
    ),
  ],
);
