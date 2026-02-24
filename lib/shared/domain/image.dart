class Image {
  final String id;
  final DateTime createdAt;

  double? similarity;

  Image({required this.id, required this.createdAt, this.similarity});
}
