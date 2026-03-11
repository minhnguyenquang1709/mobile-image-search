import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/core/constants/route.constant.dart';
import 'package:mobile_image_search/feature/gallery/presentation/home_screen.dart';
import 'package:mobile_image_search/feature/gallery/presentation/image_view_screen.dart';
import 'package:photo_manager/photo_manager.dart';

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
        final assetEntity = extra?['assetEntity'] as AssetEntity;
        return ImageViewScreen(assetEntity: assetEntity);
      },
    ),
  ],
);
