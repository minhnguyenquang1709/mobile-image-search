import 'dart:typed_data';

import 'package:mobile_image_search/src/shared/domain/model/media.dart';

class IndexingTask {
  final String taskId;
  final MediaAsset media;
  IndexingTask({required this.taskId, required this.media});
}

class IndexingResult {
  final String taskId;
  final MediaAsset media;
  final Float32List? embedding;
  final String? errorMessage;

  IndexingResult.success(this.taskId, this.media, this.embedding)
    : errorMessage = null;
  IndexingResult.failure(this.taskId, this.media, this.errorMessage)
    : embedding = null;
}
