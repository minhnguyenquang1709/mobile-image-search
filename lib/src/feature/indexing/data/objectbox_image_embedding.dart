import 'package:objectbox/objectbox.dart';
import '../../../core/constants/config_constant.dart';

@Entity()
class ObjectBoxImageEmbedding {
  @Id()
  int id = 0;

  @Index()
  @Unique(onConflict: ConflictStrategy.replace)
  String assetId;

  String title;
  int mediaType;
  int duration;

  @HnswIndex(
    dimensions: AppConfig.embeddingDimensions,
    distanceType: VectorDistanceType.cosine,
  )
  @Property(type: PropertyType.floatVector)
  List<double> embedding;

  @Property(type: PropertyType.date)
  DateTime indexedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime mediaCreatedAt;

  @Property(type: PropertyType.date)
  DateTime mediaModifiedAt;

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  ObjectBoxImageEmbedding({
    required this.assetId,
    required this.title,
    required this.mediaType,
    this.duration = 0,
    required this.embedding,
    required this.mediaCreatedAt,
    required this.mediaModifiedAt,
  });
}
