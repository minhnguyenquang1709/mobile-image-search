import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/core/config/theme.dart';
import 'package:mobile_image_search/core/router/router_config.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // await appRepo.init();
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
    // TODO: implement build
    return MaterialApp.router(
      title: 'Smart Image Gallery',
      theme: lightTheme,
      // home: MyHomePage(title: 'Local Image Search', repo: repo),
      // routes: <String, WidgetBuilder>{
      //   '/full-image': (context) => FullImageViewer(),
      // },
      // initialRoute: '/',
      routerConfig: navigationRouter,
    );
  }
}
