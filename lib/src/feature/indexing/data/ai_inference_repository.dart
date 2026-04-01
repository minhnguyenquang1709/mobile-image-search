import 'dart:io';
import 'dart:typed_data';

import 'package:mobile_image_search/src/feature/indexing/data/onnx_data_source.dart';
import 'package:mobile_image_search/src/feature/indexing/domain/ai_inference_interface.dart';

class OnnxInferenceRepository implements IAiInferenceRepositoryInterface {
  OnnxInferenceRepository(this._onnxDataSource);

  final OnnxDataSource _onnxDataSource;

  @override
  Future<Float32List> encodeImage(File imageFile) async {
    return await _onnxDataSource.encodeImage(imageFile);
  }

  @override
  Future<Float32List> encodeText(String text) async {
    return await _onnxDataSource.encodeText(text);
  }
}
