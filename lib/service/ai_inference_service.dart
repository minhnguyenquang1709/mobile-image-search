import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:mobile_image_search/config/config.dart';
import 'package:mobile_image_search/utils/logger.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

const Model _model = Model.vitBase16QuickGelu_224;

class AiInferenceService {
  static final AiInferenceService _instance = AiInferenceService._internal();

  factory AiInferenceService() {
    return _instance;
  }
  AiInferenceService._internal();

  final ort = OnnxRuntime();
  OrtSession? textEncoder;
  OrtSession? imageEncoder;

  final int imageSize = _model.specs.imageSize;
  final int contextLength = _model.specs.contextLength;

  final List<double> mean = _model.specs.mean;
  final List<double> std = _model.specs.std;

  final _logger = loggers[LoggerName.AiInferenceService]!;

  /// load the models
  Future<void> init() async {
    try {
      final String textEncoderPath = _model.textEncoderPath;
      final String imageEncoderPath = _model.imageEncoderPath;
      // if (textEncoderPath == null || imageEncoderPath == null) {
      //   throw Exception(
      //     'Model paths not found in configuration for model: $_model',
      //   );
      // }

      final OrtSessionOptions options = OrtSessionOptions(
        providers: [
          OrtProvider.XNNPACK,
          // OrtProvider.NNAPI,
          // OrtProvider.CORE_ML,
          OrtProvider.CPU,
        ],
      );

      textEncoder = await ort.createSessionFromAsset(
        textEncoderPath,
        options: options,
      );
      imageEncoder = await ort.createSessionFromAsset(
        imageEncoderPath,
        options: options,
      );

      if (textEncoder == null || imageEncoder == null) {
        throw Exception('Failed to load models for model: $_model');
      }

      // DEBUG
      // get model metadata
      final textEncoderMetadata = await textEncoder!.getMetadata();
      _logger.printLog('Producer: ${textEncoderMetadata.producerName}');
      _logger.printLog('Graph name: ${textEncoderMetadata.graphName}');
      _logger.printLog(
        'Domain: ${textEncoderMetadata.domain}, Version: ${textEncoderMetadata.version}',
      );
      _logger.printLog('Description: ${textEncoderMetadata.description}');
      _logger.printLog(
        'Custom metadata map: ${textEncoderMetadata.customMetadataMap}',
      );

      final imageEncoderMetadata = await imageEncoder!.getMetadata();
      _logger.printLog('Producer: ${imageEncoderMetadata.producerName}');
      _logger.printLog('Graph name: ${imageEncoderMetadata.graphName}');
      _logger.printLog(
        'Domain: ${imageEncoderMetadata.domain}, Version: ${imageEncoderMetadata.version}',
      );
      _logger.printLog('Description: ${imageEncoderMetadata.description}');
      _logger.printLog(
        'Custom metadata map: ${imageEncoderMetadata.customMetadataMap}',
      );

      // get model input/output info
      final textEncoderInputInfo = await textEncoder!.getInputInfo();
      for (final info in textEncoderInputInfo) {
        _logger.printLog(
          'Text Encoder Input - Name: ${info['name']}, Type: ${info['type']}, Shape: ${info['shape']}',
        );
      }
      final textEncoderOutputInfo = await textEncoder!.getOutputInfo();
      for (final info in textEncoderOutputInfo) {
        _logger.printLog(
          'Text Encoder Output - Name: ${info['name']}, Type: ${info['type']}, Shape: ${info['shape']}',
        );
      }

      final imageEncoderInputInfo = await imageEncoder!.getInputInfo();
      for (final info in imageEncoderInputInfo) {
        _logger.printLog(
          'Image Encoder Input - Name: ${info['name']}, Type: ${info['type']}, Shape: ${info['shape']}',
        );
      }
      final imageEncoderOutputInfo = await imageEncoder!.getOutputInfo();
      for (final info in imageEncoderOutputInfo) {
        _logger.printLog(
          'Image Encoder Output - Name: ${info['name']}, Type: ${info['type']}, Shape: ${info['shape']}',
        );
      }
    } catch (e) {
      _logger.printLog('Error initializing AiInferenceService: $e');
      rethrow;
    }
  }

  /// tokenize text
  ///
  /// create tensor
  ///
  /// feed to model and get output
  ///
  /// explicitly dispose OrtValue after use
  ///
  /// Tip: reuse OrtValue for better performance
  Future<Float32List> encodeText(String text) async {
    if (textEncoder == null) {
      throw Exception('Text encoder model is not initialized');
    }

    throw UnimplementedError();
  }

  /// transform image into model's expected input
  ///
  /// create tensor
  Future<Float32List> encodeImage(File imageFile) async {
    if (imageEncoder == null) {
      throw Exception('Image encoder model is not initialized');
    }

    try {
      _logger.printLog('Encoding image: ${imageFile.path}');

      // Read and decode image using image package
      final imageBytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) {
        throw Exception('Failed to decode image');
      }

      // Resize to target size
      final resizedImage = img.copyResize(
        decodedImage,
        width: imageSize,
        height: imageSize,
        interpolation: img.Interpolation.linear,
      );

      // Prepare normalized input [1, 3, imageSize, imageSize]
      final inputData = Float32List(1 * 3 * imageSize * imageSize);

      int idx = 0;
      // Convert to CHW format (channels, height, width) and normalize
      for (int c = 0; c < 3; c++) {
        for (int h = 0; h < imageSize; h++) {
          for (int w = 0; w < imageSize; w++) {
            final pixel = resizedImage.getPixel(w, h);
            final int pixelValue;
            switch (c) {
              case 0:
                pixelValue = pixel.r.toInt();
                break;
              case 1:
                pixelValue = pixel.g.toInt();
                break;
              case 2:
                pixelValue = pixel.b.toInt();
                break;
              default:
                pixelValue = 0;
            }
            // Normalize: (pixel/255.0 - mean) / std
            inputData[idx++] = (pixelValue / 255.0 - mean[c]) / std[c];
          }
        }
      }

      // Create input tensor
      final inputOrt = await OrtValue.fromList(inputData, [
        1,
        3,
        imageSize,
        imageSize,
      ]);

      // Run inference - using actual input name 'image'
      final inputs = {'image': inputOrt};
      final outputs = await imageEncoder!.run(inputs);

      // Get output embedding - output name is 'image_output'
      final outputOrt = outputs['image_output']!;
      final embeddings = await outputOrt.asFlattenedList();

      // Convert to Float32List
      final result = Float32List.fromList(
        embeddings.map((e) => e as double).toList(),
      );

      // DEBUG: Print first few pixel values to verify they differ
      _logger.printLog(
        'First 12 bytes (3 pixels RGBA): ${[for (int i = 0; i < 12; i++) imageBytes[i]]}',
      );
      _logger.printLog(
        'Image encoded successfully, embedding size: ${result.length}',
      );

      // Cleanup
      await inputOrt.dispose();
      for (final output in outputs.values) {
        await output.dispose();
      }

      return result;
    } catch (e) {
      _logger.printLog('Error encoding image: $e');
      rethrow;
    }
    // throw UnimplementedError();
  }

  Future<void> dispose() async {
    await textEncoder?.close();
    await imageEncoder?.close();
  }
}
