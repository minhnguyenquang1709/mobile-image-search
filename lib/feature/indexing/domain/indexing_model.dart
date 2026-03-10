import 'dart:typed_data';

// enum EIndexingStatus { pending, processing, failed }

class IndexingTask {
  final String assetId;
  IndexingTask({required this.assetId});
}

class IndexingResult {
  final String assetId;
  final Float32List? embedding;
  final String? errorMessage;

  IndexingResult.success(this.assetId, this.embedding) : errorMessage = null;
  IndexingResult.failure(this.assetId, this.errorMessage) : embedding = null;
}
