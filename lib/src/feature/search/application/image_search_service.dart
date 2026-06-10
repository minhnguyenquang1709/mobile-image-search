import 'package:flutter/foundation.dart';
import 'package:mobile_image_search/objectbox.g.dart';
import 'package:mobile_image_search/src/feature/indexing/data/background_worker_data_source.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_image_embedding.dart';
import 'package:mobile_image_search/src/feature/indexing/data/objectbox_store_repository.dart';
import 'package:mobile_image_search/src/feature/search/domain/model/search_result.dart';
import 'package:objectbox/objectbox.dart';

/// App Service class to handle image search logic
class SearchService {
  final ObjectBoxClient _objectBoxClient;
  final BackgroundWorkerDataSource _bgWorkerClient;

  SearchService({
    required ObjectBoxClient objectBoxClient,
    required BackgroundWorkerDataSource bgWorkerClient,
  }) : _objectBoxClient = objectBoxClient,
       _bgWorkerClient = bgWorkerClient;

  /// Input validation:
  ///
  /// - trim whitespace, check empty
  ///
  /// - split by whitespace, add '</w>' to each word's end
  ///
  /// - check with model's vocab, if not exist, throw error
  ///
  /// - generate embedding
  ///
  /// - search in database
  Future<List<SearchResultMatch>> searchByPhrase(String query) async {
    debugPrint("[SearchService] Starting search for query: '$query'");
    if (query.trim().isEmpty) {
      throw Exception("Search query cannot be empty");
    }

    // generate embedding for text query
    final queryVector = await _bgWorkerClient.encodeText(query);

    final Box<ObjectBoxImageEmbedding> imageEmbeddingBox = _objectBoxClient
        .store
        .box<ObjectBoxImageEmbedding>();

    // get semantic search results
    final searchQuery = imageEmbeddingBox
        .query(
          ObjectBoxImageEmbedding_.embedding.nearestNeighborsF32(
            queryVector,
            100,
          ),
        )
        .build();
    final searchResults = await searchQuery.findWithScoresAsync();

    debugPrint(
      "[SearchService] Search completed with ${searchResults.length} results",
    );

    final domainResults = searchResults.map((result) {
      return SearchResultMatch(
        assetId: result.object.assetId,
        cosineScore: result.score,
      );
    }).toList();

    // debug: print to terminal
    for (var i = 0; i < domainResults.length; i++) {
      debugPrint(
        "[SearchService] Result ${i + 1}: assetId=${domainResults[i].assetId}, cosineScore=${domainResults[i].cosineScore}",
      );
    }

    return domainResults;
  }
}
