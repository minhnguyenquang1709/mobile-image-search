import 'package:objectbox/objectbox.dart';
import '../../../constants/config_constant.dart';

@Entity()
class ImageObjectBox {
  @Id()
  int id = 0;

  @Index()
  @Unique(onConflict: ConflictStrategy.replace)
  String assetId;

  String title;

  @HnswIndex(
    dimensions: AppConfig.embeddingDimensions,
    distanceType: VectorDistanceType.cosine,
  )
  @Property(type: PropertyType.floatVector)
  List<double> embedding;

  @Property(type: PropertyType.date)
  DateTime indexedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime modifiedAt;

  ImageObjectBox({
    required this.assetId,
    required this.title,
    required this.embedding,
    required this.createdAt,
    required this.modifiedAt,
  });
}
