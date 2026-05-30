import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_repository.dart';
import 'package:mobile_image_search/src/feature/indexing/domain/image_embedding_interface.dart';

class ImageEmbeddingRepo implements IImageEmbedding {
  final ObjectBoxClient _objectBoxClient;

  ImageEmbeddingRepo(this._objectBoxClient);
}
