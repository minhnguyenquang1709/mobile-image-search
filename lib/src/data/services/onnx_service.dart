import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_image_search/src/core/constants/config_constant.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:mobile_image_search/src/domain/bpe_tokenizer.dart';

/// This class abstracts the interaction with AI models
///
/// OnnxRuntime: Main entry point for creating sessions and configuring global options
///
/// OrtSession: Represents a loaded ML model for running inference
///
/// OrtValue: Represents tensor data for inputs and outputs
///
/// OrtSessionOptions: Configuration options for session creation
///
/// OrtRunOptions: Configuration options for inference execution
class OnnxService {
  final ort = OnnxRuntime();
  OrtSession? textEncoder;
  OrtSession? imageEncoder;
  BpeTokenizer? tokenizer;

  final int imageSize = Model.specs.imageSize;
  final int contextLength = Model.specs.contextLength;

  final List<double> mean = Model.specs.mean;
  final List<double> std = Model.specs.std;

  // performance tracking
  // int _totalImagesProcessed = 0;
  // int _totalProcessingTimeMs = 0;
  // Directory? _performanceLogDirectory;

  /// Helper method to save in-processing images to device cache
  // Future<void> _saveDebugImage(
  //   img.Image image,
  //   String title,
  //   String stepName,
  // ) async {
  //   if (!Platform.isAndroid) return;

  //   final directory = await getExternalStorageDirectory();
  //   if (directory == null) return;

  //   final filePath = '${directory.path}/$title-$stepName.jpg';
  //   File(filePath).writeAsBytesSync(img.encodeJpg(image, quality: 100));
  // }

  /// load the models
  Future<void> init({
    required String textEncoderExtractedPath,
    required String imageEncoderExtractedPath,
    required String bpeVocabExtractedPath,
    required String bpeMergesExtractedPath,
  }) async {
    try {
      final String textEncoderPath = (textEncoderExtractedPath != null)
          ? textEncoderExtractedPath
          : Model.textEncoderAssetPath;
      final String imageEncoderPath = (imageEncoderExtractedPath != null)
          ? imageEncoderExtractedPath
          : Model.imageEncoderAssetPath;

      final providers = await ort.getAvailableProviders();
      debugPrint(
        '[OnnxDataSource] Available ONNX Runtime providers: $providers',
      );

      List<OrtProvider> availableProviders = [];
      for (final provider in [
        // OrtProvider.NNAPI,
        OrtProvider.CORE_ML,
        OrtProvider.XNNPACK,
        OrtProvider.CPU,
      ]) {
        if (providers.contains(provider)) {
          availableProviders.add(provider);
        }
      }

      final OrtSessionOptions options = OrtSessionOptions(
        providers: availableProviders,
        interOpNumThreads: 2,
        intraOpNumThreads: 2,
      );

      final List<OrtProvider> textEncoderProviders = availableProviders
          .where((provider) => provider != OrtProvider.NNAPI)
          .toList();
      final OrtSessionOptions textEncoderOptions = OrtSessionOptions(
        providers: textEncoderProviders,
        interOpNumThreads: 2,
        intraOpNumThreads: 2,
      );

      textEncoder = await ort.createSession(
        textEncoderPath,
        options: textEncoderOptions,
      );
      imageEncoder = await ort.createSession(
        imageEncoderPath,
        options: options,
      );
      debugPrint(
        "[OnnxDataSource] Text encoder & image encoder initialized successfully",
      );

      tokenizer = BpeTokenizer();
      await tokenizer?.init(
        vocabExtractedPath: bpeVocabExtractedPath,
        mergesExtractedPath: bpeMergesExtractedPath,
      );
      debugPrint("[OnnxDataSource] Tokenizer initialized successfully");

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
    } catch (e) {
      debugPrint('[OnnxDataSource] Error in initialization: $e');
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

    List<int> tokenIds = tokenizer!.tokenizeText(text);
    final List<String> inputNames = textEncoder!.inputNames;
    final List<String> outputNames = textEncoder!.outputNames;
    debugPrint('[OnnxDataSource] Input names for text encoder: $inputNames');
    debugPrint('[OnnxDataSource] Output names for text encoder: $outputNames');

    final String inputName = inputNames.first;
    final String outputName = outputNames.first;

    final inputs = {
      inputName: await OrtValue.fromList(Int64List.fromList(tokenIds), [
        1,
        contextLength,
      ]),
    };
    final output = await textEncoder!.run(inputs);
    debugPrint('[OnnxDataSource] Text encoded successfully, output keys:\n');
    final outputKeys = output.keys.toList();
    for (int i = 0; i < outputKeys.length; i++) {
      debugPrint(
        '[OnnxDataSource] Output $i: ${outputKeys[i]} - ${output[outputKeys[i]].runtimeType}',
      );
    }

    return await output[outputName]!.asFlattenedList().then(
      (embeddings) =>
          Float32List.fromList(embeddings.map((e) => e as double).toList()),
    );
  }

  /// Create vector embedding from image's thumbnail bytes
  ///
  /// Apply letterboxing
  Future<Float32List> encodeImageLetterboxing(Uint8List thumbnailBytes) async {
    if (imageEncoder == null) {
      throw Exception('Image encoder model is not initialized');
    }

    try {
      // decode
      final img.Image? decodedImage = img.decodeImage(thumbnailBytes);

      if (decodedImage == null) {
        throw Exception('Failed to decode image');
      }

      // resize
      final int targetSize = Model.specs.imageSize;

      // get longer image side for contain
      final bool isWidthLonger = decodedImage.width > decodedImage.height;

      final img.Image resizedImage = img.copyResize(
        decodedImage,
        width: isWidthLonger ? targetSize : null,
        height: isWidthLonger ? null : targetSize,
        interpolation: img.Interpolation.average,
      );

      // contain (create pads)
      final int xOffset = (targetSize - resizedImage.width) ~/ 2;
      final int yOffset = (targetSize - resizedImage.height) ~/ 2;

      final img.Image paddedImage = img.Image(
        width: targetSize,
        height: targetSize,
        numChannels: 3,
      );

      img.compositeImage(
        paddedImage,
        resizedImage,
        dstX: xOffset,
        dstY: yOffset,
      );

      // convert to CHW (channels, height, width) and normalize.
      // read the whole image once as a flat RGB buffer instead of getPixel per
      // pixel, which allocates a Pixel object each call.
      final Uint8List pixels = paddedImage.getBytes(
        order: img.ChannelOrder.rgb,
      );
      final int height = paddedImage.height;
      final int width = paddedImage.width;

      final Float32List imageInputData = Float32List(1 * 3 * height * width);
      int idx = 0;
      final List<double> mean = Model.specs.mean;
      final List<double> std = Model.specs.std;
      for (int c = 0; c < 3; c++) {
        for (int h = 0; h < height; h++) {
          for (int w = 0; w < width; w++) {
            final int pixelValue = pixels[(h * width + w) * 3 + c];
            imageInputData[idx++] = (pixelValue / 255.0 - mean[c]) / std[c];
          }
        }
      }

      // create tensor
      final OrtValue inputImageOrt = await OrtValue.fromList(imageInputData, [
        1,
        3,
        paddedImage.height,
        paddedImage.width,
      ]);

      // run inference
      final inputs = {'image': inputImageOrt};
      final outputs = await imageEncoder!.run(inputs);

      // Get output embedding - output name is 'image_output'
      final outputOrt = outputs['image_output']!;
      final embeddings = await outputOrt.asFlattenedList();

      // Convert to Float32List
      final result = Float32List.fromList(
        embeddings.map((e) => e as double).toList(),
      );

      // cleanup
      await inputImageOrt.dispose();
      for (final output in outputs.values) {
        await output.dispose();
      }

      return result;
    } catch (e) {
      debugPrint('[OnnxDataSource] Error encoding image: $e');
      // task.finish();
      rethrow;
    }
  }

  /// Create vector embedding from image's thumbnail bytes
  ///
  /// Resize the shorter side to the model input size, then center crop a square.
  Future<Float32List> encodeImageCenterCrop(Uint8List thumbnailBytes) async {
    if (imageEncoder == null) {
      throw Exception('Image encoder model is not initialized');
    }

    try {
      // decode
      final img.Image? decodedImage = img.decodeImage(thumbnailBytes);

      if (decodedImage == null) {
        throw Exception('Failed to decode image');
      }

      final int targetSize = Model.specs.imageSize;

      // resize so the shorter side equals the target size (keeps aspect ratio)
      final bool isWidthShorter = decodedImage.width < decodedImage.height;

      final img.Image resizedImage = img.copyResize(
        decodedImage,
        width: isWidthShorter ? targetSize : null,
        height: isWidthShorter ? null : targetSize,
        interpolation: img.Interpolation.average,
      );

      // center crop a targetSize x targetSize square
      final int xOffset = (resizedImage.width - targetSize) ~/ 2;
      final int yOffset = (resizedImage.height - targetSize) ~/ 2;

      final img.Image croppedImage = img.copyCrop(
        resizedImage,
        x: xOffset,
        y: yOffset,
        width: targetSize,
        height: targetSize,
      );

      // convert to CHW (channels, height, width) and normalize.
      // Read the whole image as a flat RGB byte buffer once (HWC layout) instead
      // of calling getPixel per pixel, which allocates a Pixel object each time.
      final Uint8List pixels = croppedImage.getBytes(
        order: img.ChannelOrder.rgb,
      );
      final int height = croppedImage.height;
      final int width = croppedImage.width;

      final Float32List imageInputData = Float32List(1 * 3 * height * width);
      int idx = 0;
      for (int c = 0; c < 3; c++) {
        for (int h = 0; h < height; h++) {
          for (int w = 0; w < width; w++) {
            final int pixelValue = pixels[(h * width + w) * 3 + c];
            imageInputData[idx++] = (pixelValue / 255.0 - mean[c]) / std[c];
          }
        }
      }

      // create tensor
      final OrtValue inputImageOrt = await OrtValue.fromList(imageInputData, [
        1,
        3,
        height,
        width,
      ]);

      // run inference
      final inputs = {'image': inputImageOrt};
      final outputs = await imageEncoder!.run(inputs);

      // Get output embedding - output name is 'image_output'
      final outputOrt = outputs['image_output']!;
      final embeddings = await outputOrt.asFlattenedList();

      // Convert to Float32List
      final result = Float32List.fromList(
        embeddings.map((e) => e as double).toList(),
      );

      // cleanup
      await inputImageOrt.dispose();
      for (final output in outputs.values) {
        await output.dispose();
      }

      return result;
    } catch (e) {
      debugPrint('[OnnxDataSource] Error encoding image: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    await textEncoder?.close();
    await imageEncoder?.close();
  }
}
