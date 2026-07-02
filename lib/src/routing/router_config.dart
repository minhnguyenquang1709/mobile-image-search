import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/src/common_widgets/settings_screen.dart';
import 'package:mobile_image_search/src/core/constants/route_constant.dart';
import 'package:mobile_image_search/src/common_widgets/nested_navigation_widget.dart';
import 'package:mobile_image_search/src/feature/gallery/views/album_opened_screen.dart';
import 'package:mobile_image_search/src/feature/gallery/views/album_screen.dart';
import 'package:mobile_image_search/src/feature/gallery/views/main_gallery_screen.dart';
import 'package:mobile_image_search/src/feature/gallery/views/full_media_view_screen.dart';
import 'package:mobile_image_search/src/feature/gallery/views/trash_screen.dart';
import 'package:mobile_image_search/src/feature/evaluation/presentation/evaluation_screen.dart';
import 'package:mobile_image_search/src/shared/domain/model/album.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

// GlobalKey: unique identifier, provide access to `BuildContext`, `State`, `Widget`
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorHomeKey = GlobalKey<NavigatorState>();
final _shellNavigatorAlbumsKey = GlobalKey<NavigatorState>();
final _shellNavigatorTrashKey = GlobalKey<NavigatorState>();

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
            return ScaffoldWithNestedNavigation(
              navigationShell: navigationShell,
            );
          },
      branches: [
        // top-level branch (aka tabs in app navigation bar)
        // 0. home screen branch
        StatefulShellBranch(
          navigatorKey: _shellNavigatorHomeKey,
          routes: [
            // the GoRoutes at this level will be rendered inside [navigationShell]
            // root screen
            GoRoute(
              path: RouteConstants.home,
              builder: (BuildContext context, GoRouterState state) =>
                  MainGalleryScreen(),
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

        // 1. album screen branch
        StatefulShellBranch(
          navigatorKey: _shellNavigatorAlbumsKey,
          routes: [
            GoRoute(
              path: RouteConstants.albums,
              builder: (context, state) {
                return AlbumScreen();
              },
              routes: [
                // opened album - nested so it keeps the shell's bottom bar
                GoRoute(
                  path: 'view',
                  builder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>?;
                    final album = extra?['album'] as Album;
                    return AlbumOpenedScreen(currentAlbum: album);
                  },
                ),
              ],
            ),
          ],
        ),

        // 2. trash screen branch
        StatefulShellBranch(
          navigatorKey: _shellNavigatorTrashKey,
          routes: [
            GoRoute(
              path: RouteConstants.trashScreen,
              builder: (context, state) {
                return TrashScreen();
              },
            ),
          ],
        ),

        // 3. settings screen branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RouteConstants.settings,
              builder: (context, state) => SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    // route outside of shell, full screen dialog, NestedNavigationShell app bar and bottom navigation bar will be hidden
    // full media viewer
    GoRoute(
      path: RouteConstants.mediaView,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final image = extra?['media'] as MediaAsset;
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

    // model evaluation (developer tool)
    GoRoute(
      path: RouteConstants.evaluation,
      builder: (context, state) {
        return const EvaluationScreen();
      },
    ),
  ],
);
