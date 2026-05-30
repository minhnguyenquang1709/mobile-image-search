import 'package:flutter/foundation.dart';

@immutable
class ImageEmbedding {
  final String assetId;
  final List<double> embedding;
  final DateTime createdAt;

  const ImageEmbedding({
    required this.assetId,
    required this.embedding,
    required this.createdAt,
  });
}
