import 'package:mobile_image_search/model/image.entity.dart';
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

class SearchResult {
  final Image image;
  final double score;

  SearchResult({required this.image, required this.score});
}
