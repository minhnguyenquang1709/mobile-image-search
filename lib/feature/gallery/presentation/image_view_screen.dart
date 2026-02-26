import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class ImageViewScreen extends StatelessWidget {
  const ImageViewScreen({super.key, required this.assetId});
  final String assetId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: AssetEntity.fromId(assetId),
      builder: (context, snapshot) {
        // loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // error or null state
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Scaffold(body: Center(child: Icon(Icons.error)));
        }

        // successful state
        final assetEntity = snapshot.data!;
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
      },
    );
  }
}
