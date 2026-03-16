import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/core/constants/route.constant.dart';
import 'package:mobile_image_search/feature/gallery/presentation/home_screen.dart';
import 'package:mobile_image_search/feature/gallery/presentation/image_view_screen.dart';
import 'package:mobile_image_search/shared/domain/image_model.dart'
    as image_model;

// final _rootNavigatorKey = GlobalKey<NavigatorState>();

final topLevelNavigationRouter = GoRouter(
  initialLocation: RouteConstants.home,
  routes: [
    // StatefulShellRoute.indexedStack(
    //   branches: [
    //     // top-level routes (aka tabs in app navigation bar)
    //     StatefulShellBranch(routes: []),
    //     StatefulShellBranch(routes: []),
    //   ],
    //   builder: (context, state, navigationShell) {
    //     // the UI shell (parent widget that holds the navigation bar and the child navigator)
    //     // return ScaffoldWithNestedNavigation(navigationShell: navigationShell);
    //     return Container();
    //   },
    // ),
    GoRoute(
      path: RouteConstants.home,
      builder: (context, state) => HomeScreen(),
    ),
    GoRoute(
      path: RouteConstants.imageViewer,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final image = extra?['image'] as image_model.Image;
        return ImageViewScreen(image: image);
      },
    ),
  ],
);
