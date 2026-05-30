import 'package:objectbox/objectbox.dart';

@Entity()
class ObjectBoxTrashEntry {
  @Id()
  int id = 0;

  @Unique(onConflict: ConflictStrategy.replace)
  @Index()
  String assetId;

  @Index()
  DateTime trashedAt;

  ObjectBoxTrashEntry({required this.assetId, required this.trashedAt});
}

@Entity()
class ObjectBoxAlbumTrashEntry {
  @Id()
  int id = 0;

  /// - Android: MediaStore.Images.Media.BUCKET_ID
  ///
  /// - iOS: localIdentifier
  @Unique(onConflict: ConflictStrategy.replace)
  @Index()
  String albumId;

  @Index()
  DateTime trashedAt;

  ObjectBoxAlbumTrashEntry({required this.albumId, required this.trashedAt});
}
