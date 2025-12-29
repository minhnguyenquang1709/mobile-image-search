import 'package:flutter/services.dart';
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

      debugLogger.printLog('Text encoder');
      debugLogger.printLog('Input names: ${textEncoder?.inputNames}');
      debugLogger.printLog('Output names: ${textEncoder?.outputNames}');
      debugLogger.printLog('Image encoder');
      debugLogger.printLog('Input names: ${imageEncoder?.inputNames}');
      debugLogger.printLog('Output names: ${imageEncoder?.outputNames}');
    } catch (e) {
      final modelConfig = models[_model];
      final textEncoderPath = modelConfig!['textEncoder'];
      final bytes = await rootBundle.load(textEncoderPath!);
      debugLogger.printLog(
        'Text encoder model size: ${bytes.lengthInBytes} bytes',
      );
      debugLogger.printLog('Error initializing AiInferenceService: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    await textEncoder?.close();
    await imageEncoder?.close();
  }
}
