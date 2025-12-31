import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mobile_image_search/config/ai_model.dart';
import 'package:mobile_image_search/utils/logger.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

class AiInferenceService {
  static final AiInferenceService _instance = AiInferenceService._internal();

  factory AiInferenceService() {
    return _instance;
  }
  AiInferenceService._internal();

  final ort = OnnxRuntime();
  OrtSession? textEncoder;
  OrtSession? imageEncoder;

  Model _model = Model.vitBase32SigLip2_256;

  static const int imageSize = 256;
  static const int contextLength = 64;

  final List<double> mean = [0.5, 0.5, 0.5];
  final List<double> std = [0.5, 0.5, 0.5];

  final _logger = loggers['AiInferenceService']!;

  /// load the models
  Future<void> init() async {
    try {
      final modelConfig = models[_model];
      if (modelConfig == null) {
        throw Exception('Model configuration not found for model: $_model');
      }

      final textEncoderPath = modelConfig['textEncoder'];
      final imageEncoderPath = modelConfig['imageEncoder'];
      if (textEncoderPath == null || imageEncoderPath == null) {
        throw Exception(
          'Model paths not found in configuration for model: $_model',
        );
      }

      final OrtSessionOptions options = OrtSessionOptions(
        providers: [OrtProvider.XNNPACK, OrtProvider.CPU],
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

    try {} catch (e) {
      _logger.printLog('Error encoding text: $e');
      rethrow;
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

    } catch (e) {
      _logger.printLog('Error encoding image: $e');
      rethrow;
    }
    throw UnimplementedError();
  }

  Future<void> dispose() async {
    await textEncoder?.close();
    await imageEncoder?.close();
  }
}
