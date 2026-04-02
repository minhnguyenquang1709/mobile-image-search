import 'dart:typed_data';

class SearchResult {
  final String assetId;
  final double similarity;

  SearchResult({required this.assetId, required this.similarity});
}

class EncodeTextTask {
  final String taskId;
  final String query;

  EncodeTextTask({required this.taskId, required this.query});
}

class EncodeTextResult {
  final String taskId;
  final Float32List embedding;
  final String? errorMessage;

  EncodeTextResult.success(this.taskId, this.embedding) : errorMessage = null;
  EncodeTextResult.failure(this.taskId, this.errorMessage)
    : embedding = Float32List(0);
}
