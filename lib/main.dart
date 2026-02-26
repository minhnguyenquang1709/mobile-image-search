import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/core/router/router_config.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // init services
  // final photoGalleryService = PhotoGalleryService();
  // final vectorStoreService = StoreService();
  // final indexingQueueService = IndexingQueueService();
  // final aiInferenceService = AiInferenceService();

  // init app repository
  // final appRepo = AppRepository(
  //   photoGalleryService: photoGalleryService,
  //   vectorStoreService: vectorStoreService,
  //   indexingQueueService: indexingQueueService,
  //   aiInferenceService: aiInferenceService,
  // );
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

// class MyHomePage extends StatefulWidget {
//   final AppRepository repo;
//   MyHomePage({super.key, required this.title, required this.repo});

//   final String title;

//   final PhotoGalleryService photoGalleryService = PhotoGalleryService();

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   void requestPermission() {
//     widget.repo.requestGalleryAccess().then((granted) {
//       setState(() {});
//     });
//   }

//   // @override
//   // Future<void> dispose() {
//   //   super.dispose();
//   //   widget.repo.dispose();
//   // }

//   @override
//   Widget build(BuildContext context) {
//     AppRepository repo = widget.repo;

//     return Scaffold(
//       // appBar: AppBar(
//       //   backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//       //   title: Text(widget.title),
//       // ),
//       body: Flex(
//         direction: Axis.vertical,
//         children: [
//           Expanded(
//             child: Center(
//               child: Builder(
//                 builder: (context) {
//                   if (!repo.isPermissionGranted) {
//                     return TextButton(
//                       onPressed: requestPermission,
//                       style: TextButton.styleFrom(backgroundColor: Colors.blue),
//                       child: const Text("Request Permission"),
//                     );
//                   }

//                   // render images from gallery
//                   final List<AssetEntity> assets = repo.assets;
//                   if (assets.isEmpty) {
//                     return const Text("No images found in gallery");
//                   }

//                   void handleImageClick(AssetEntity assetEntity) async {
//                     // Navigator.pushNamed(
//                     //   context,
//                     //   '/full-image',
//                     //   arguments: assetEntity,
//                     // );

//                     /** TODO: remove debug */
//                     try {
//                       final Float32List imageEmbedding = await repo.encodeImage(
//                         assetEntity,
//                       );

//                       // repo.logger.printLog("Text embedding: $textEmbedding");
//                       // repo.logger.printLog("Image embedding: $imageEmbedding");
//                       // repo.logger.printLog(
//                       //   "Cosine similarity: ${cosineSimilarity(imageEmbedding, textEmbedding)}",
//                       // );
//                     } catch (e) {
//                       repo.logger.printLog('Error encoding image/text: $e');
//                     }
//                   }

//                   return Padding(
//                     padding: const EdgeInsets.only(
//                       left: Config.gridViewGutter,
//                       right: Config.gridViewGutter,
//                     ),
//                     child: GridView.builder(
//                       scrollDirection: Axis.vertical,
//                       gridDelegate:
//                           const SliverGridDelegateWithFixedCrossAxisCount(
//                             crossAxisCount: Config.imagesPerRow,
//                             crossAxisSpacing: 5,
//                             mainAxisSpacing: 5,
//                           ),
//                       itemCount: assets.length,
//                       cacheExtent: Config
//                           .gridViewCacheExtent, // top and bottom outside screen preload area
//                       itemBuilder: (context, index) {
//                         // one image tile
//                         return GestureDetector(
//                           onTap: () {
//                             repo.logger.printLog(
//                               'Image clicked: ${assets[index].id}',
//                             );
//                             handleImageClick(assets[index]);
//                           },
//                           child: AssetEntityImage(
//                             assets[index],
//                             isOriginal: false,
//                             thumbnailSize: const ThumbnailSize(
//                               Config.thumbnailWidth,
//                               Config.thumbnailHeight,
//                             ),
//                             thumbnailFormat: ThumbnailFormat.jpeg,
//                             fit: BoxFit.cover,
//                           ),
//                         );
//                       },
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
