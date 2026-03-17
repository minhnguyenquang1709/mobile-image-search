import 'package:objectbox/objectbox.dart';
import '../../../core/config/config.dart';

@Entity()
class ImageObjectBox {
  @Id()
  int id = 0;

  @Index()
  @Unique(onConflict: ConflictStrategy.replace)
  String assetId;

  @HnswIndex(
    dimensions: AppConfig.embeddingDimensions,
    distanceType: VectorDistanceType.cosine,
  )
  @Property(type: PropertyType.floatVector)
  List<double> embedding;

  @Property(type: PropertyType.date)
  DateTime indexedAt = DateTime.now();

  ImageObjectBox({required this.assetId, required this.embedding});
}
