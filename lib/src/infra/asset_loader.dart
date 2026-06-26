import 'dart:io';

import 'package:flutter/services.dart';
import 'package:mobile_image_search/src/core/constants/config_constant.dart';
import 'package:path_provider/path_provider.dart';

/// Responsible for extracting bundled model and tokenizer assets from the
/// Flutter asset bundle to the device filesystem so they can be read by
/// native code (e.g. ONNX Runtime) and background isolates.
///
/// Call [extractAll] once during app initialization. After that, the extracted
/// file paths are available as plain getters.
class AssetLoader {
  String? _textEncoderPath;
  String? _imageEncoderPath;
  String? _vocabPath;
  String? _mergesPath;

  String get textEncoderPath {
    if (_textEncoderPath == null) {
      throw ArgumentError("AssetLoader.extractAll() has not been called yet");
    }
    return _textEncoderPath!;
  }

  String get imageEncoderPath {
    if (_imageEncoderPath == null) {
      throw ArgumentError("AssetLoader.extractAll() has not been called yet");
    }
    return _imageEncoderPath!;
  }

  String get vocabPath {
    if (_vocabPath == null) {
      throw ArgumentError("AssetLoader.extractAll() has not been called yet");
    }
    return _vocabPath!;
  }

  String get mergesPath {
    if (_mergesPath == null) {
      throw ArgumentError("AssetLoader.extractAll() has not been called yet");
    }
    return _mergesPath!;
  }

  /// Extracts all required model and tokenizer assets from the bundle to the
  /// application support directory. Skips files that already exist on disk.
  ///
  /// Throws an [Exception] if any file is missing after extraction.
  Future<void> extractAll() async {
    final appSupportDir = await getApplicationSupportDirectory();
    final base = appSupportDir.path;
    final sep = Platform.pathSeparator;

    _textEncoderPath = '$base$sep${Model.textEncoderAssetPath}';
    _imageEncoderPath = '$base$sep${Model.imageEncoderAssetPath}';
    _vocabPath = '$base$sep${Model.tokenizerDir}${sep}vocab.json';
    _mergesPath = '$base$sep${Model.tokenizerDir}${sep}merges.txt';

    await _extractAsset(
      assetKey: Model.textEncoderAssetPath,
      destPath: _textEncoderPath!,
    );
    await _extractAsset(
      assetKey: Model.imageEncoderAssetPath,
      destPath: _imageEncoderPath!,
    );
    await _extractAsset(
      assetKey: '${Model.tokenizerDir}/vocab.json',
      destPath: _vocabPath!,
    );
    await _extractAsset(
      assetKey: '${Model.tokenizerDir}/merges.txt',
      destPath: _mergesPath!,
    );

    _verify();
  }

  /// Copies a single asset from the bundle to [destPath] if it does not
  /// already exist on disk.
  Future<void> _extractAsset({
    required String assetKey,
    required String destPath,
  }) async {
    final file = File(destPath);
    if (await file.exists()) return;

    final data = await rootBundle.load(assetKey);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
  }

  /// Verifies all expected files exist; throws if any are missing.
  void _verify() {
    final missing = <String>[];

    for (final entry in {
      'text encoder': _textEncoderPath!,
      'image encoder': _imageEncoderPath!,
      'BPE vocab': _vocabPath!,
      'BPE merges': _mergesPath!,
    }.entries) {
      if (!File(entry.value).existsSync()) {
        missing.add(entry.key);
      }
    }

    if (missing.isNotEmpty) {
      throw Exception(
        '[AssetLoader] Failed to extract the following assets: ${missing.join(', ')}',
      );
    }
  }
}
