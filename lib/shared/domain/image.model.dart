class Image {
  /// The ID of the asset.
  ///
  /// - Android: _id column in MediaStore database.
  ///
  /// - iOS/macOS: localIdentifier.
  final String id;
  final DateTime createdAt;

  double? similarity;

  Image({required this.id, required this.createdAt, this.similarity});
}
