import 'package:flutter/material.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:mobile_image_search/shared/domain/image_model.dart'
    as image_model;

class ImageViewScreen extends StatelessWidget {
  const ImageViewScreen({super.key, required this.image});
  final image_model.Image image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Flex(
        direction: Axis.vertical,
        children: [
          Expanded(
            child: Center(
              child: AssetEntityImage(image.assetEntity, isOriginal: true),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(child: Text(image.metadata.name)),
    );
  }
}
