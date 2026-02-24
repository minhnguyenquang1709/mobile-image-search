import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/config/config.dart';
import 'package:mobile_image_search/feature/gallery/presentation/gallery_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final galleryAsyncState = ref.watch(galleryProvider);
    return Scaffold(
      // appBar: AppBar(title: Text("Home")),
      body: Flex(
        direction: Axis.vertical,
        children: [Expanded(child: Center())],
      ),
    );
  }
}
