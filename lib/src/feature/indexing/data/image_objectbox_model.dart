import 'package:mobile_image_search/src/constants/common_constant.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
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
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime modifiedAt;

  ImageObjectBox({
    required this.assetId,
    required this.title,
    required this.mediaType,
    this.duration = 0,
    required this.embedding,
    required this.createdAt,
    required this.modifiedAt,
  });

  /// Helper method to convert to domain model
  MediaAsset toMediaAsset() {
    return MediaAsset(
      assetId: assetId,
      title: title,
      createDateTime: createdAt,
      modifiedDateTime: modifiedAt,
      mediaType: mediaType == 1 ? EMediaType.video : EMediaType.image,
      duration: duration,
    );
  }
}
