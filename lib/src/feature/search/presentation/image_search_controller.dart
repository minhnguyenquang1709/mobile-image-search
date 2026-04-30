import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/feature/gallery/application/gallery_service.dart';
import 'package:mobile_image_search/src/feature/search/application/image_search_service.dart';
import 'package:mobile_image_search/src/feature/search/domain/model/search_result.dart';

class ImageSearchController extends AsyncNotifier<List<SearchResultMatch>> {
  String searchQuery = "";

  @override
  Future<List<SearchResultMatch>> build() async {
    // initial state, empty
    return [];
  }

  /// Call search service to get results, then update state
  Future<void> searchByCaption() async {
    final query = searchQuery.trim();
    if (query.isEmpty) {
      state = AsyncValue.data([]);
      return;
    }

    try {
      state = const AsyncValue.loading();

      // Get search service and search
      final searchService = await ref.watch(imageSearchServiceProvider.future);
      final List<SearchResultMatch> searchResults = await searchService
          .searchByCaption(query);

      // Get all media objects to match with search results
      final galleryService = ref.read(galleryServiceProvider);
      final allMedia = await galleryService.getAllMetadata();
      // Create a map for quick lookup: assetId -> Media
      final mediaMap = {for (var media in allMedia) media.assetId: media};

      // Convert SearchResult to SearchResultItem (with Media + similarity)
      // final resultItems = searchResults
      //     .map((result) {
      //       final MediaAsset? media = mediaMap[result.assetId];
      //       if (media != null) {
      //         return SearchResultMatch(
      //           assetId: result.assetId,
      //           cosineScore: result.similarity,
      //         );
      //       }
      //       return null;
      //     })
      //     .whereType<SearchResultItem>()
      //     .toList();

      // Sort by similarity ascending (lower scores = better matches)
      searchResults.sort((a, b) => a.cosineScore.compareTo(b.cosineScore));

      for (var i = 0; i < searchResults.take(5).length; i++) {}

      state = AsyncValue.data(searchResults);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void updateSearchQuery(String query) {
    searchQuery = query;
  }
}

final imageSearchController =
    AsyncNotifierProvider<ImageSearchController, List<SearchResultMatch>>(
      () => ImageSearchController(),
    );
