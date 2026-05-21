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
