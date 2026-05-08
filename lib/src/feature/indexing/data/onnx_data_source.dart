import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_image_search/src/constants/config_constant.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:mobile_image_search/src/utils/debug.dart';
import 'package:mobile_image_search/src/utils/logger.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:mobile_image_search/src/utils/bpe_tokenizer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

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

  // performance tracking
  int _totalImagesProcessed = 0;
  int _totalProcessingTimeMs = 0;
  Directory? _performanceLogDirectory;

  /// Helper method to save in-processing images to device cache
  Future<void> _saveDebugImage(
    img.Image image,
    String title,
    String stepName,
  ) async {
    if (!Platform.isAndroid) return;

    final directory = await getExternalStorageDirectory();
    if (directory == null) return;

    final filePath = '${directory.path}/$title-$stepName.jpg';
    File(filePath).writeAsBytesSync(img.encodeJpg(image, quality: 100));
  }

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

      List<OrtProvider> availableProviders = [];
      for (final provider in [
        // OrtProvider.NNAPI, // error
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
      // final testText = "white dog";
      // final tokenIds = tokenizer!.tokenize(testText);
      // _logger.printLog('Token IDs for "$testText": $tokenIds');
      // _logger.printLog('Decoded: ${tokenizer!.decode(tokenIds)}');
      // final encodedTestText = await encodeText(testText);
      // _logger.printLog('Vector: $encodedTestText');

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
  Future<Float32List> encodeImage(MediaAsset mediaAsset) async {
    final TimelineTask task = TimelineTask();
    final Stopwatch stopwatch = Stopwatch();
    if (isDebugOrProfileMode) {
      task.start('Encode Image Pipeline');
      stopwatch.start();
    }

    if (imageEncoder == null) {
      throw Exception('Image encoder model is not initialized');
    }

    try {
      // _logger.printLog(
      //   'Encoding image: ${mediaAsset.title}, assetId: ${mediaAsset.assetId}',
      // );

      // FAST
      // read and preprocess image
      final AssetEntity? assetEntity = await AssetEntity.fromId(
        mediaAsset.assetId,
      );

      if (assetEntity == null) {
        throw Exception(
          'AssetEntity not found for assetId: ${mediaAsset.assetId}',
        );
      }
      // END FAST

      // FAST
      const ThumbnailOption thumbnailOption = ThumbnailOption(
        size: ThumbnailSize(
          500,
          500,
        ), // return thumbnail with max width or height of 500px
      );

      // measure platform channel
      final fetchTask = TimelineTask(parent: task);

      if (isDebugOrProfileMode) {
        fetchTask.start('Fetch Thumbnail from Platform Channel');
      }

      // platform channel call goes through Flutter Platform Thread (OS main thread)
      Uint8List? thumbnailBytes = await assetEntity.thumbnailDataWithOption(
        thumbnailOption,
      );
      if (isDebugOrProfileMode) {
        fetchTask.finish();
      }

      if (thumbnailBytes == null) {
        throw Exception(
          'Failed to get thumbnail for assetId: ${mediaAsset.assetId}',
        );
      }
      // END FAST

      // get physical file pathway
      // final File? imageFile = await assetEntity.file;

      // if (imageFile == null) {
      //   throw Exception(
      //     'Failed to get image file for assetId: ${mediaAsset.assetId}',
      //   );
      // }

      // final Uint8List imageBytes = await imageFile.readAsBytes();

      // measure dart image decoding (CPU)
      final decodeTask = TimelineTask(parent: task);
      if (isDebugOrProfileMode) {
        decodeTask.start('Decode Image');
      }

      // decode
      final img.Image? decodedImage = img.decodeImage(thumbnailBytes);
      if (isDebugOrProfileMode) {
        decodeTask.finish();
      }

      if (decodedImage == null) {
        throw Exception(
          'Failed to decode image for assetId: ${mediaAsset.assetId}',
        );
      }

      // measure image resizing (CPU)
      final resizeTask = TimelineTask(parent: task);
      if (isDebugOrProfileMode) {
        resizeTask.start('Resize Image');
      }

      // resize
      final int targetSize = Model.specs.imageSize;
      // get shorter image side
      final bool isWidthShorter = decodedImage.width < decodedImage.height;

      final img.Image resizedImage = img.copyResize(
        decodedImage,
        width: isWidthShorter ? targetSize : null,
        height: isWidthShorter ? null : targetSize,
        interpolation: img.Interpolation.average,
      );

      // center crop
      final int xOffset = (resizedImage.width - targetSize) ~/ 2; // center crop
      final int yOffset =
          (resizedImage.height - targetSize) ~/ 2; // center crop
      final img.Image croppedImage = img.copyCrop(
        resizedImage,
        x: xOffset,
        y: yOffset,
        width: targetSize,
        height: targetSize,
      );
      if (isDebugOrProfileMode) {
        resizeTask.finish();
      }

      // measure image normalization and CHW conversion (CPU)
      final normalizeTask = TimelineTask(parent: task);
      if (isDebugOrProfileMode) {
        normalizeTask.start('Normalize and Convert Image Data to CHW');
      }

      // convert to CHW (channels, height, width) and normalize
      final Float32List imageInputData = Float32List(
        1 * 3 * croppedImage.width * croppedImage.height,
      );
      int idx = 0;
      final List<double> mean = Model.specs.mean;
      final List<double> std = Model.specs.std;
      for (int c = 0; c < 3; c++) {
        for (int h = 0; h < croppedImage.height; h++) {
          for (int w = 0; w < croppedImage.width; w++) {
            final pixel = croppedImage.getPixel(
              w,
              h,
            ); // need another method, getPixel returns a new Pixel object, expensive
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
            imageInputData[idx++] = (pixelValue / 255.0 - mean[c]) / std[c];
          }
        }
      }
      if (isDebugOrProfileMode) {
        normalizeTask.finish();
      }

      // BLOCKING UI (flutter_onnxruntime version < 1.7.0 does not have taskQueue in native code)
      // measure ONNX runtime inference time
      final onnxTask = TimelineTask(parent: task);
      if (isDebugOrProfileMode) {
        onnxTask.start('ONNX Runtime Inference for Image');
      }

      // create tensor
      final OrtValue inputImageOrt = await OrtValue.fromList(imageInputData, [
        1,
        3,
        croppedImage.height,
        croppedImage.width,
      ]);

      // run inference
      final inputs = {'image': inputImageOrt};
      final outputs = await imageEncoder!.run(inputs);
      if (isDebugOrProfileMode) {
        onnxTask.finish();
      }
      // END BLOCKING UI

      // measure output processing
      final outputProcessTask = TimelineTask(parent: task);
      if (isDebugOrProfileMode) {
        outputProcessTask.start('Process ONNX Output');
      }

      // Get output embedding - output name is 'image_output'
      final outputOrt = outputs['image_output']!;
      final embeddings = await outputOrt.asFlattenedList();

      // Convert to Float32List
      final result = Float32List.fromList(
        embeddings.map((e) => e as double).toList(),
      );
      if (isDebugOrProfileMode) {
        outputProcessTask.finish();
      }

      // measure disposal time
      final disposeTask = TimelineTask(parent: task);
      if (isDebugOrProfileMode) {
        disposeTask.start('Dispose OrtValues');
      }

      // cleanup
      await inputImageOrt.dispose();
      for (final output in outputs.values) {
        await output.dispose();
      }
      if (isDebugOrProfileMode) {
        disposeTask.finish();
        task.finish();
      }

      // performance logging
      if (isDebugOrProfileMode) {
        _performanceLogDirectory ??= await getExternalStorageDirectory();

        if (_performanceLogDirectory != null) {
          final logFile = File(
            '${_performanceLogDirectory!.path}/indexing_performance_log.csv',
          );

          final elapsedMs = stopwatch.elapsedMilliseconds;
          _totalImagesProcessed++;
          _totalProcessingTimeMs += elapsedMs;
          final avgMs = (_totalProcessingTimeMs / _totalImagesProcessed)
              .round();
          final imageResolution = '${assetEntity.width}x${assetEntity.height}';

          if (!logFile.existsSync()) {
            logFile.writeAsStringSync('Title,Resolution,Time (s),Avg (s)\n');
          }
          logFile.writeAsStringSync(
            '${mediaAsset.title},$imageResolution,${elapsedMs / 1000},${avgMs / 1000}\n',
            mode: FileMode.append,
          );
        }
      }

      // save debug step images for inspection
      if (isDebugOrProfileMode) {
        // original image
        final File? originImage = await assetEntity.originFile;
        if (originImage != null) {
          await _saveDebugImage(
            img.decodeImage(originImage.readAsBytesSync())!,
            mediaAsset.title,
            '00_original_image',
          );
        }

        // DEBUG: thumbnail
        await _saveDebugImage(decodedImage, mediaAsset.title, '01_thumbnail');

        // DEBUG: resized image
        await _saveDebugImage(
          resizedImage,
          mediaAsset.title,
          '02_resized_image',
        );

        // DEBUG: cropped image
        await _saveDebugImage(
          croppedImage,
          mediaAsset.title,
          '03_cropped_image',
        );
      }

      return result;
    } catch (e) {
      _logger.printLog('Error encoding image: $e');
      task.finish();
      rethrow;
    }
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
