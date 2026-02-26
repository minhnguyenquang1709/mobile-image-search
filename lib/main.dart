import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/core/router/router_config.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // await appRepo.init();
    runApp(ProviderScope(child: MyApp()));
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              children: [
                Text("Error initializing app services: ${e.toString()}"),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      // home: MyHomePage(title: 'Local Image Search', repo: repo),
      // routes: <String, WidgetBuilder>{
      //   '/full-image': (context) => FullImageViewer(),
      // },
      // initialRoute: '/',
      routerConfig: navigationRouter,
    );
  }
}
