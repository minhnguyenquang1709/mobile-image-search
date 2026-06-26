import 'package:flutter/foundation.dart';

@immutable
class ModelSpecs {
  final String folderName;
  final List<double> mean;
  final List<double> std;
  final int imageSize;
  final int contextLength;

  const ModelSpecs({
    required this.folderName,
    required this.mean,
    required this.std,
    required this.imageSize,
    required this.contextLength,
  });
}

class Model {
  // static const vitBase32SigLip2_256 = ModelSpecs(
  //   folderName: "ViT-B-32-SigLIP2-256",
  //   mean: [0.5, 0.5, 0.5],
  //   std: [0.5, 0.5, 0.5],
  //   imageSize: 256,
  //   contextLength: 64,
  // );

  // static const vitBase16SigLipi18_256 = ModelSpecs(
  //   folderName: "ViT-B-16-SigLIP-i18n-256",
  //   mean: [0.5, 0.5, 0.5],
  //   std: [0.5, 0.5, 0.5],
  //   imageSize: 256,
  //   contextLength: 77,
  // );

  static const vitBase16QuickGelu_224 = ModelSpecs(
    folderName: "ViT-B-16-quickgelu",
    mean: [0.48145466, 0.4578275, 0.40821073],
    std: [0.26862954, 0.26130258, 0.27577711],
    imageSize: 224,
    contextLength: 77,
  );

  static const vitBase16Dfn2b_224 = ModelSpecs(
    folderName: "ViT-B-16_dfn2b",
    mean: [0.48145466, 0.4578275, 0.40821073],
    std: [0.26862954, 0.26130258, 0.27577711],
    imageSize: 224,
    contextLength: 77,
  );

  static const vitLarge14QuickGelu_224 = ModelSpecs(
    folderName: "ViT-L-14-quickgelu",
    mean: [0.48145466, 0.4578275, 0.40821073],
    std: [0.26862954, 0.26130258, 0.27577711],
    imageSize: 224,
    contextLength: 77,
  );

  static const ModelSpecs specs = vitBase16Dfn2b_224;

  static String get textEncoderAssetPath =>
      'assets/openclip/${specs.folderName}/text_encoder_quant.onnx';
  static String get imageEncoderAssetPath =>
      'assets/openclip/${specs.folderName}/image_encoder_quant.onnx';

  static String get tokenizerDir =>
      'assets/openclip/${specs.folderName}/tokenizer';

  static String get displayName => specs.folderName;
}

class AppConfig {
  static const int embeddingDimensions = 512;
  static const int maxIndexAttempts = 3;
  static const int batchSize = 32;
}

abstract class UIConfig {
  // common
  static const double appBarHeight = 50;

  // Home Screen UI
  static const double gridViewGutter = 5;
  static const int thumbnailWidth = 100;
  static const int thumbnailHeight = 100;
  static const int thumbnailsPerRow = 4;
  static const double gridViewCacheExtent = 1000;
  static const double gridCrossAxisSpacing = 5;
  static const double gridMainAxisSpacing = 5;
  static const double imageGroupSpacing = 15;
  static const double homeScreenScrollbarThumbMinHeight = 40;

  // Image Search Screen UI
  static const double searchButtonIconHeight = 50;
  static const double searchBarHeight = 50;

  // number of assets fetched per page while scanning for filename search
  static const int filenameScanPageSize = 200;
}
