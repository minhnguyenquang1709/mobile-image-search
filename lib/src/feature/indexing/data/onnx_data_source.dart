import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_image_search/src/constants/config_constant.dart';
import 'package:mobile_image_search/src/utils/logger.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:mobile_image_search/src/utils/bpe_tokenizer.dart';

/// OnnxRuntime: Main entry point for creating sessions and configuring global options
///
/// OrtSession: Represents a loaded ML model for running inference
///
/// OrtValue: Represents tensor data for inputs and outputs
///
/// OrtSessionOptions: Configuration options for session creation
///
/// OrtRunOptions: Configuration options for inference execution
class OnnxDataSource {
  final ort = OnnxRuntime();
  OrtSession? textEncoder;
  OrtSession? imageEncoder;
  BpeTokenizer? tokenizer;

  final int imageSize = Model.specs.imageSize;
  final int contextLength = Model.specs.contextLength;

  final List<double> mean = Model.specs.mean;
  final List<double> std = Model.specs.std;

  final _logger = loggers[LoggerName.onnxDataSource]!;

  /// load the models
  Future<void> init({
    String? textEncoderExtractedPath,
    String? imageEncoderExtractedPath,
    String? bpeVocabExtractedPath,
    String? bpeMergesExtractedPath,
  }) async {
    try {
      final String textEncoderPath = (textEncoderExtractedPath != null)
          ? textEncoderExtractedPath
          : Model.textEncoderAssetPath;
      final String imageEncoderPath = (imageEncoderExtractedPath != null)
          ? imageEncoderExtractedPath
          : Model.imageEncoderAssetPath;

      final providers = await ort.getAvailableProviders();
      _logger.printLog('Available ONNX Runtime providers: $providers');

      final OrtSessionOptions options = OrtSessionOptions(
        providers: [
          OrtProvider.NNAPI,
          OrtProvider.CORE_ML,
          OrtProvider.XNNPACK,
          OrtProvider.CPU,
        ],
        intraOpNumThreads: 4,
      );

      textEncoder = await ort.createSession(textEncoderPath, options: options);
      imageEncoder = await ort.createSession(
        imageEncoderPath,
        options: options,
      );
      tokenizer = BpeTokenizer();
      await tokenizer?.init(
        vocabExtractedPath: bpeVocabExtractedPath,
        mergesExtractedPath: bpeMergesExtractedPath,
      );

      if (textEncoder == null || imageEncoder == null) {
        throw Exception(
          'Failed to load models for model: ${Model.displayName}',
        );
      }

      if (tokenizer == null) {
        throw Exception(
          'Failed to initialize tokenizer for model: ${Model.displayName}',
        );
      }

      // DEBUG
      // tokenizer test
      final testText = "white dog";
      final tokenIds = tokenizer!.tokenize(testText);
      _logger.printLog('Token IDs for "$testText": $tokenIds');
      _logger.printLog('Decoded: ${tokenizer!.decode(tokenIds)}');

      // embedding test
      final encodedTestText = await encodeText(testText);
      _logger.printLog('Vector: $encodedTestText');

      // final File testImageFile = await rootBundle
      //     .load('assets/images/rider-187.jpg')
      //     .then((byteData) {
      //       final tempDir = Directory.systemTemp;
      //       final tempFilePath = File('${tempDir.path}/rider-187.jpg');
      //       return File.fromUri(Uri.parse(tempFilePath.path));
      //     });
      // final encodedTestImage = await encodeImage(testImageFile);
      // _logger.printLog('Image Vector: $encodedTestImage');

      // get model metadata
      // final textEncoderMetadata = await textEncoder!.getMetadata();
      // _logger.printLog('Producer: ${textEncoderMetadata.producerName}');
      // _logger.printLog('Graph name: ${textEncoderMetadata.graphName}');
      // _logger.printLog(
      //   'Domain: ${textEncoderMetadata.domain}, Version: ${textEncoderMetadata.version}',
      // );
      // _logger.printLog('Description: ${textEncoderMetadata.description}');
      // _logger.printLog(
      //   'Custom metadata map: ${textEncoderMetadata.customMetadataMap}',
      // );

      // final imageEncoderMetadata = await imageEncoder!.getMetadata();
      // _logger.printLog('Producer: ${imageEncoderMetadata.producerName}');
      // _logger.printLog('Graph name: ${imageEncoderMetadata.graphName}');
      // _logger.printLog(
      //   'Domain: ${imageEncoderMetadata.domain}, Version: ${imageEncoderMetadata.version}',
      // );
      // _logger.printLog('Description: ${imageEncoderMetadata.description}');
      // _logger.printLog(
      //   'Custom metadata map: ${imageEncoderMetadata.customMetadataMap}',
      // );

      // get model input/output info
      // final textEncoderInputInfo = await textEncoder!.getInputInfo();
      // for (final info in textEncoderInputInfo) {
      //   _logger.printLog(
      //     'Text Encoder Input - Name: ${info['name']}, Type: ${info['type']}, Shape: ${info['shape']}',
      //   );
      // }
      // final textEncoderOutputInfo = await textEncoder!.getOutputInfo();
      // for (final info in textEncoderOutputInfo) {
      //   _logger.printLog(
      //     'Text Encoder Output - Name: ${info['name']}, Type: ${info['type']}, Shape: ${info['shape']}',
      //   );
      // }

      // final imageEncoderInputInfo = await imageEncoder!.getInputInfo();
      // for (final info in imageEncoderInputInfo) {
      //   _logger.printLog(
      //     'Image Encoder Input - Name: ${info['name']}, Type: ${info['type']}, Shape: ${info['shape']}',
      //   );
      // }
      // final imageEncoderOutputInfo = await imageEncoder!.getOutputInfo();
      // for (final info in imageEncoderOutputInfo) {
      //   _logger.printLog(
      //     'Image Encoder Output - Name: ${info['name']}, Type: ${info['type']}, Shape: ${info['shape']}',
      //   );
      // }
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

    if (tokenizer == null) {
      throw Exception('Tokenizer is not initialized');
    }

    List<int> tokenIds = tokenizer!.tokenize(text);
    final List<String> inputNames = textEncoder!.inputNames;
    final List<String> outputNames = textEncoder!.outputNames;
    _logger.printLog('Input names for text encoder: $inputNames');
    _logger.printLog('Output names for text encoder: $outputNames');

    final String inputName = inputNames.first;
    final String outputName = outputNames.first;

    final inputs = {
      inputName: await OrtValue.fromList(Int64List.fromList(tokenIds), [
        1,
        contextLength,
      ]),
    };
    final output = await textEncoder!.run(inputs);
    _logger.printLog('Text encoded successfully, output keys:\n');
    final outputKeys = output.keys.toList();
    for (int i = 0; i < outputKeys.length; i++) {
      _logger.printLog(
        'Output $i: ${outputKeys[i]} - ${output[outputKeys[i]].runtimeType}',
      );
    }

    return await output[outputName]!.asFlattenedList().then(
      (embeddings) =>
          Float32List.fromList(embeddings.map((e) => e as double).toList()),
    );
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

      // preprocess image: resize, normalize, convert to CHW format
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
      _logger.printLog('First 12 vector values: ${result.sublist(0, 12)}');
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

// final onnxDataSourceProvider = FutureProvider((ref) async {
//   final dataSource = OnnxDataSource();
//   await dataSource.init();

//   return dataSource;
// });
