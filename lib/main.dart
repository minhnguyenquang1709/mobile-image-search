import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/constants/theme_constant.dart';
import 'package:mobile_image_search/src/routing/router_config.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    runApp(ProviderScope(child: AppLifecycleWrapper()));
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              children: [Text("Error initializing app: ${e.toString()}")],
            ),
          ),
        ),
      ),
    );
  }
}

class AppLifecycleWrapper extends StatefulWidget {
  const AppLifecycleWrapper({super.key});

  @override
  State<StatefulWidget> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends State<AppLifecycleWrapper> {
  late final AppLifecycleListener _lifecycleListener;
  late AppLifecycleState? _state;

  @override
  void initState() {
    super.initState();
    _state = SchedulerBinding.instance.lifecycleState;
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _handleStateChange,
    );
  }

  void _handleStateChange(AppLifecycleState state) {
    setState(() {
      _state = state;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Smart Image Gallery',
      theme: lightTheme,
      routerConfig: topLevelNavigationRouter,
      showPerformanceOverlay: false,
    );
  }
}
