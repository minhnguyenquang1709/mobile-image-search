import 'package:flutter/material.dart';
import 'package:mobile_image_search/main.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class FullImageViewer extends StatelessWidget {
  AssetEntity assetEntity;
  FullImageViewer({super.key, required AssetEntity assetEntity});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Padding(
        padding: EdgeInsets.only(
          left: Config.gridViewGutter,
          right: Config.gridViewGutter,
        ),
        child: AssetEntityImage(assetEntity),
      ),
    );
  }
}
