import 'package:objectbox/objectbox.dart';
import '../../core/config/config.dart';

@Entity()
class ImageObjectBox {
  int id;

  @Index()
  @Unique(onConflict: ConflictStrategy.replace)
  String assetId;

  @HnswIndex(
    dimensions: AppConfig.embeddingDimensions,
    distanceType: VectorDistanceType.cosine,
  )
  @Property(type: PropertyType.floatVector)
  List<double>? embedding;

  @Property(type: PropertyType.dateUtc)
  DateTime indexedAt;

  ImageObjectBox(this.id, this.assetId, this.embedding, this.indexedAt);
}
