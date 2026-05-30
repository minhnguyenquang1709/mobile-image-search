import 'package:objectbox/objectbox.dart';

/// A model representing an album, which can contain multiple media assets.
class Album {
  /// Android: MediaStore.Images.Media.BUCKET_ID.
  ///
  /// iOS/macOS: localIdentifier.
  final String id;
  final String title;
  String? description;

  Album({required this.id, required this.title, this.description});
}

@Entity()
class ObjectBoxAlbum {
  @Id()
  int objectBoxId;

  /// - Android: MediaStore.Images.Media.BUCKET_ID
  ///
  /// - iOS: localIdentifier
  @Unique(onConflict: ConflictStrategy.fail)
  String platformId;

  String title;
  String? description;

  ObjectBoxAlbum({
    this.objectBoxId = 0,
    required this.title,
    this.description,
    required this.platformId,
  });
}
