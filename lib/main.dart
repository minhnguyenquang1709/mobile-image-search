import 'package:flutter/material.dart';
import 'package:mobile_image_search/repository/app_repository.dart';
import 'package:mobile_image_search/service/indexing_queue_service.dart';
import 'package:mobile_image_search/service/photo_gallery_service.dart';
import 'package:mobile_image_search/service/vector_store_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // init services
  final photoGalleryService = PhotoGalleryService();
  final vectorStoreService = VectorStoreService();
  final indexingQueueService = IndexingQueueService();

  // init app repository
  final appRepo = AppRepository(
    photoGalleryService: photoGalleryService,
    vectorStoreService: vectorStoreService,
    indexingQueueService: indexingQueueService,
  );
  runApp(MyApp(repository: appRepo));
}

class MyApp extends StatelessWidget {
  final AppRepository repository;
  const MyApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: MyHomePage(title: 'Local Image Search'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({super.key, required this.title});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "Access Granted: ${widget.photoGalleryService.isGalleryAccessGranted}",
            ),
            Builder(
              builder: (context) {
                if (widget.photoGalleryService.isGalleryAccessGranted) {
                  return const Text("Permission already granted");
                }
                return TextButton(
                  onPressed: requestPermission,
                  style: TextButton.styleFrom(backgroundColor: Colors.blue),
                  child: Text("Request Permission"),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
