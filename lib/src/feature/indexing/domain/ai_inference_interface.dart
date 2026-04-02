import 'dart:io';
import 'dart:typed_data';

abstract class IAiInferenceRepository {
  Future<Float32List> encodeImage(File imageFile);
  Future<Float32List> encodeText(String text);
}
