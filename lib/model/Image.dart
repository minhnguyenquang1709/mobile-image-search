import 'package:objectbox/objectbox.dart';
import '../config/ai_model.dart';

@Entity()
class Image {
  @Id()
  int id = 0;

  @Index()
  @Unique(onConflict: ConflictStrategy.replace)
  String assetId;

  @HnswIndex(dimensions: dimensions, distanceType: VectorDistanceType.cosine)
  @Property(type: PropertyType.floatVector)
  List<double>? embedding;

  @Property(type: PropertyType.dateUtc)
  DateTime indexedAt;

  Image({
    this.id = 0,
    required this.assetId,
    required this.embedding,
    required this.indexedAt,
  });
}
