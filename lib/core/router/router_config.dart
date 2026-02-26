import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/core/constants/route.constant.dart';
import 'package:mobile_image_search/feature/gallery/presentation/home_screen.dart';
import 'package:mobile_image_search/feature/gallery/presentation/image_view_screen.dart';

final navigationRouter = GoRouter(
  routes: [
    GoRoute(
      path: RouteConstants.home,
      builder: (context, state) => HomeScreen(),
    ),
    GoRoute(
      path: RouteConstants.imageViewer,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final assetId = extra?['assetId'] as String?;
        return ImageViewScreen(assetId: assetId!);
      },
    ),
  ],
);
