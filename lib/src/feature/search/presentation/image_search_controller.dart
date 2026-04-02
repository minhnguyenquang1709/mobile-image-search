import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/shared/domain/model/media.dart';

class ImageSearchController extends AsyncNotifier<List<Media>> {
  String searchQuery = "";
  List<Media> searchResults = [];

  @override
  Future<List<Media>> build() async {
    // initial state, can be empty or some default data
    return [];
  }

  /// Call search service to get results, then update state
  Future<void> searchByCaption() async {
    final query = searchQuery.trim();
  }

  void updateSearchQuery(String query) {
    searchQuery = query;
  }
}

final imageSearchController =
    AsyncNotifierProvider<ImageSearchController, List<Media>>(
      () => ImageSearchController(),
    );
