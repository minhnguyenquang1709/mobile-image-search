import 'package:objectbox/objectbox.dart';

@Entity()
class SearchQuery {
  @Id()
  int id = 0;

  @Index()
  String text;

  @Property(type: PropertyType.dateUtc)
  DateTime createdAt;

  SearchQuery({this.id = 0, required this.text, required this.createdAt});
}
