import 'package:flutter/material.dart';
import 'package:mobile_image_search/repository/app_repository.dart';
import 'package:mobile_image_search/service/ai_inference_service.dart';
import 'package:mobile_image_search/service/indexing_queue_service.dart';
import 'package:mobile_image_search/service/photo_gallery_service.dart';
import 'package:mobile_image_search/service/vector_store_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // init services
  final photoGalleryService = PhotoGalleryService();
  final vectorStoreService = VectorStoreService();
  final indexingQueueService = IndexingQueueService();
  final aiInferenceService = AiInferenceService();

  // init app repository
  final appRepo = AppRepository(
    photoGalleryService: photoGalleryService,
    vectorStoreService: vectorStoreService,
    indexingQueueService: indexingQueueService,
    aiInferenceService: aiInferenceService,
  );
  try {
    await appRepo.init();
    runApp(MyApp(repo: appRepo));
  } catch (e) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text("Error initializing app services")),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final AppRepository repo;
  const MyApp({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: MyHomePage(title: 'Local Image Search', repo: repo),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final AppRepository repo;
  MyHomePage({super.key, required this.title, required this.repo});

  final String title;

  final PhotoGalleryService photoGalleryService = PhotoGalleryService();

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void requestPermission() {
    widget.photoGalleryService.requestGalleryAccess().then((granted) {
      setState(() {});
    });
  }

  // @override
  // Future<void> dispose() {
  //   super.dispose();
  //   widget.repo.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    AppRepository repo = widget.repo;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text("Access Granted: ${repo.isPermissionGranted}"),
            Builder(
              builder: (context) {
                if (repo.isPermissionGranted) {
                  return const Text("Permission already granted");
                }
                return TextButton(
                  onPressed: requestPermission,
                  style: TextButton.styleFrom(backgroundColor: Colors.blue),
                  child: Text("Request Permission"),
                );
              },
            ),
            Builder(
              builder: (context) {
                if (repo.assets.isEmpty) {
                  return const Text("No images cached");
                }
                return Column(
                  children: repo.assets
                      .map(
                        (assetEntity) => Text(
                          "Image path: ${assetEntity.relativePath}${assetEntity.title}",
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
