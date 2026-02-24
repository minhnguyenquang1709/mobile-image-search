import 'package:flutter/material.dart';
import 'package:mobile_image_search/config/config.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class ImageInfoViewer extends StatelessWidget {
  final AssetEntity assetEntity;
  const ImageInfoViewer({super.key, required this.assetEntity});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(assetEntity.title ?? 'Image Info')),
      body: Padding(
        padding: EdgeInsets.all(Config.gridViewGutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: AssetEntityImage(
                assetEntity,
                isOriginal: true,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 20),
            Text(
              style: const TextStyle(color: Colors.amber),
              'Title: ${assetEntity.title ?? 'N/A'}',
            ),
            Text('ID: ${assetEntity.id}'),
            Text('Type: ${assetEntity.type.toString().split('.').last}'),
            Text('Width: ${assetEntity.width}'),
            Text('Height: ${assetEntity.height}'),
            Text('File Size: ${assetEntity.size} bytes'),
            Text('Creation Date: ${assetEntity.createDateTime}'),
          ],
        ),
      ),
    );
  }
}

class FullImageViewer extends StatelessWidget {
  const FullImageViewer({super.key});

  @override
  Widget build(BuildContext context) {
    final assetEntity =
        ModalRoute.of(context)!.settings.arguments as AssetEntity;
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Padding(
        padding: EdgeInsets.only(
          left: Config.gridViewGutter,
          right: Config.gridViewGutter,
        ),
        child: Stack(
          alignment: AlignmentGeometry.center,
          children: [
            AssetEntityImage(
              assetEntity,
              isOriginal: true,
              fit: BoxFit.contain,
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ImageInfoViewer(assetEntity: assetEntity),
            ),
          ],
        ),
      ),
    );
  }
}
