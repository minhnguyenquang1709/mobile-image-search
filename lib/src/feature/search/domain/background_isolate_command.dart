import 'dart:typed_data';

class TextEncodingCommand {
  final String taskId;
  final String query;

  TextEncodingCommand({required this.taskId, required this.query});
}

class TextEncodingResult {
  final String taskId;
  final Float32List embedding;
  final String? errorMessage;

  TextEncodingResult.success(this.taskId, this.embedding) : errorMessage = null;
  TextEncodingResult.failure(this.taskId, this.errorMessage)
    : embedding = Float32List(0);
}

class ImageEncodingCommand {
  final String taskId;
  final String assetId;
  final String title;
  final Uint8List imageBytes;

  ImageEncodingCommand({
    required this.taskId,
    required this.assetId,
    required this.title,
    required this.imageBytes,
  });
}

class ImageEncodingResult {
  final String taskId;
  final String assetId;
  final Float32List embedding;
  final String? errorMessage;

  ImageEncodingResult.success(this.taskId, this.assetId, this.embedding)
    : errorMessage = null;
  ImageEncodingResult.failure(this.taskId, this.assetId, this.errorMessage)
    : embedding = Float32List(0);
}

class ScanGalleryCommand {
  final String taskId;

  ScanGalleryCommand({required this.taskId});
}

class StartIndexingCommand {
  final String taskId;

  StartIndexingCommand({required this.taskId});
}
