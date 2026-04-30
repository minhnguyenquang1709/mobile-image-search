import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

class SearchResultMatch {
  final MediaAsset mediaAsset;
  final double cosineScore;

  SearchResultMatch({required this.mediaAsset, required this.cosineScore});
}
