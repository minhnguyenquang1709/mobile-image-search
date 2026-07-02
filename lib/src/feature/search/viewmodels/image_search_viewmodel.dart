import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_image_search/src/core/constants/config_constant.dart';
import 'package:mobile_image_search/src/data/interfaces/image_embedding_repository_interface.dart';
import 'package:mobile_image_search/src/data/interfaces/media_asset_repository_interface.dart';
import 'package:mobile_image_search/src/feature/search/domain/filter_criteria.dart';
import 'package:mobile_image_search/src/feature/search/domain/query_validator.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

class SearchViewModel extends ChangeNotifier {
  final IMediaAssetRepository _mediaAssetRepo;
  final IImageEmbeddingRepository _imageEmbeddingRepository;
  final QueryValidator _queryValidator;

  SearchViewModel({
    required IMediaAssetRepository mediaAssetRepo,
    required IImageEmbeddingRepository imageEmbeddingRepository,
    required QueryValidator queryValidator,
  }) : _mediaAssetRepo = mediaAssetRepo,
       _imageEmbeddingRepository = imageEmbeddingRepository,
       _queryValidator = queryValidator;

  // state
  String currentTextQuery = "";
  final List<MediaAsset> searchResults = [];
  String errorMessage = "";
  bool isSearching = false;

  SearchMode mode = SearchMode.semantic;
  FilterCriteria criteria = const FilterCriteria();

  // Incremented on every new search; an in-flight scan checks it so a newer
  // search supersedes (cancels) the older one.
  int _searchGeneration = 0;

  // actions

  /// Switch between semantic and filename search. Does not auto-run a search.
  void setMode(SearchMode m) {
    mode = m;
    notifyListeners();
  }

  /// Apply a new filter and re-run the current search.
  void setCriteria(FilterCriteria c) {
    criteria = c;
    _rerun();
  }

  /// Clear all filters and re-run the current search.
  void clearFilters() {
    criteria = const FilterCriteria();
    _rerun();
  }

  /// Re-run the active mode's search with the current query + criteria.
  void _rerun() {
    final bool hasQuery = currentTextQuery.trim().isNotEmpty;

    // semantic search needs a phrase; with one, run it
    if (mode == SearchMode.semantic && hasQuery) {
      searchByEnglishPhrase(currentTextQuery);
      return;
    }

    // otherwise (filename mode, or a filter-only search with no phrase) scan
    // device media and apply the criteria. Nothing to do with neither set.
    if (hasQuery || criteria.isActive) {
      runFilenameSearch(currentTextQuery);
    } else {
      searchResults.clear();
      notifyListeners();
    }
  }

  /// Search image by an English phrase describing the image content
  Future<void> searchByEnglishPhrase(String query) async {
    currentTextQuery = query;
    searchResults.clear();
    errorMessage = "";

    // validate input
    try {
      _queryValidator.validate(query);
    } catch (e) {
      errorMessage = "$e";
      notifyListeners();
      return;
    }

    isSearching = true;
    notifyListeners();

    final int gen = ++_searchGeneration;

    try {
      // generate embedding for text query
      final Float32List queryVector = await _imageEmbeddingRepository
          .generateTextEmbedding(query);

      // perform vector search
      final List<String> assetIds = await _imageEmbeddingRepository
          .vectorSearch(queryVector);

      // a newer search superseded this one
      if (gen != _searchGeneration) return;

      // TODO: optimize with fetching in batch
      for (final assetId in assetIds) {
        try {
          final MediaAsset asset = await _mediaAssetRepo.getMediaAssetById(
            assetId,
          );
          searchResults.add(asset);
        } catch (e) {
          debugPrint(
            "[SearchViewModel] Error fetching asset by ID '$assetId': $e",
          );
        }
      }

      // date/type filters are cross-cutting - apply to semantic results too
      searchResults.retainWhere(criteria.matches);
    } finally {
      if (gen == _searchGeneration) {
        isSearching = false;
        notifyListeners();
      }
    }
  }

  /// Search by file name substring, scanning device media page by page and
  /// applying [criteria] in memory. Results stream in as pages are scanned.
  Future<void> runFilenameSearch(String query) async {
    currentTextQuery = query;
    searchResults.clear();
    errorMessage = "";
    isSearching = true;
    notifyListeners();

    final int gen = ++_searchGeneration;
    final String loweredQuery = query.toLowerCase();

    try {
      int page = 0;
      while (true) {
        final List<MediaAsset> pageAssets = await _mediaAssetRepo
            .fetchPageFiltered(
              page: page,
              pageSize: UIConfig.filenameScanPageSize,
              rangeStart: criteria.startDate,
              rangeEnd: criteria.endDate,
            );

        // a newer search superseded this one
        if (gen != _searchGeneration) return;

        for (final asset in pageAssets) {
          final bool nameMatches =
              loweredQuery.isEmpty ||
              asset.title.toLowerCase().contains(loweredQuery);
          if (nameMatches && criteria.matches(asset)) {
            searchResults.add(asset);
          }
        }
        notifyListeners();

        // last page reached
        if (pageAssets.length < UIConfig.filenameScanPageSize) break;
        page++;
      }
    } finally {
      if (gen == _searchGeneration) {
        isSearching = false;
        notifyListeners();
      }
    }
  }

  /// Reset search state when leaving search mode
  void clear() {
    currentTextQuery = "";
    searchResults.clear();
    errorMessage = "";
    isSearching = false;
    criteria = const FilterCriteria();
    _searchGeneration++;
    notifyListeners();
  }

  ImageProvider thumbnailProviderFor(String assetId) {
    return _mediaAssetRepo.thumbnailProviderFor(assetId);
  }
}
