import 'package:objectbox/objectbox.dart';

@Entity()
class ObjectboxTrashEntry {
  @Id()
  int id = 0;

  @Unique()
  @Index()
  String assetId;

  @Index()
  DateTime trashedAt;

  ObjectboxTrashEntry({required this.assetId, required this.trashedAt});
}
