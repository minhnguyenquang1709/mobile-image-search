import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class ImageViewScreen extends StatelessWidget {
  const ImageViewScreen({super.key, required this.assetEntity});
  final AssetEntity assetEntity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Flex(
        direction: Axis.vertical,
        children: [
          Expanded(
            child: Center(
              child: AssetEntityImage(assetEntity, isOriginal: true),
            ),
          ),
        ],
      ),
    );
  }
}
