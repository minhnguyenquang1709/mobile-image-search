import 'dart:typed_data';

import 'package:mobile_image_search/shared/domain/model/media.dart';

class IndexingTask {
  final Media media;
  IndexingTask({required this.media});
}

class IndexingResult {
  final Media media;
  final Float32List? embedding;
  final String? errorMessage;

  IndexingResult.success(this.media, this.embedding) : errorMessage = null;
  IndexingResult.failure(this.media, this.errorMessage) : embedding = null;
}
