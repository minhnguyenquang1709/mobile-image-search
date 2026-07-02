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

  int _currentSearchIndex = 0;

  static const int _semanticPageSize = 100;
  Float32List? _queryVector;
  int _resultLimit = _semanticPageSize; // top-K currently requested
  int _resolvedIdCount = 0;
  final Set<String> _addedIds = {}; // avoid duplicates
  bool hasMoreResults = false;
  bool isLoadingMore = false;

  // actions

  /// switch between semantic and filename search
  void setMode(SearchMode m) {
    mode = m;
    notifyListeners();
  }

  void setCriteria(FilterCriteria c) {
    criteria = c;
    _rerun();
  }

  void clearFilters() {
    criteria = const FilterCriteria();
    _rerun();
  }

  /// re-run the search with the current query + criteria.
  void _rerun() {
    final bool hasQuery = currentTextQuery.trim().isNotEmpty;

    // semantic search
    if (mode == SearchMode.semantic && hasQuery) {
      searchByEnglishPhrase(currentTextQuery);
      return;
    }

    // filename search
    if (hasQuery || criteria.isActive) {
      runFilenameSearch(currentTextQuery);
    } else {
      searchResults.clear();
      notifyListeners();
    }
  }

  /// search image by an English phrase or sentence describing the image content
  Future<void> searchByEnglishPhrase(String query) async {
    currentTextQuery = query;
    searchResults.clear();
    errorMessage = "";

    // reset paging state for the new search
    _queryVector = null;
    _resolvedIdCount = 0;
    _resultLimit = _semanticPageSize;
    _addedIds.clear();
    hasMoreResults = false;

    try {
      _queryValidator.validate(query);
    } catch (e) {
      errorMessage = "$e";
      notifyListeners();
      return;
    }

    isSearching = true;
    notifyListeners();

    final int gen = ++_currentSearchIndex;

    try {
      // generate embedding for text query
      final Float32List queryVector = await _imageEmbeddingRepository
          .generateTextEmbedding(query);
      _queryVector = queryVector;

      final List<String> assetIds = await _imageEmbeddingRepository
          .vectorSearch(queryVector, limit: _resultLimit);

      if (gen != _currentSearchIndex) return;

      await _resolveRankedIds(assetIds, gen);

      hasMoreResults = assetIds.length >= _resultLimit;
    } finally {
      if (gen == _currentSearchIndex) {
        isSearching = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreResults() async {
    if (isSearching || isLoadingMore || !hasMoreResults) return;
    if (_queryVector == null) return;

    isLoadingMore = true;
    notifyListeners();

    final int gen = _currentSearchIndex;

    try {
      _resultLimit += _semanticPageSize;
      final List<String> assetIds = await _imageEmbeddingRepository
          .vectorSearch(_queryVector!, limit: _resultLimit);

      if (gen != _currentSearchIndex) return;

      await _resolveRankedIds(assetIds, gen);

      hasMoreResults = assetIds.length >= _resultLimit;
    } finally {
      if (gen == _currentSearchIndex) {
        isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> _resolveRankedIds(List<String> assetIds, int gen) async {
    for (int i = _resolvedIdCount; i < assetIds.length; i++) {
      if (gen != _currentSearchIndex) return;

      final String assetId = assetIds[i];
      if (_addedIds.contains(assetId)) continue;

      try {
        final MediaAsset asset = await _mediaAssetRepo.getMediaAssetById(
          assetId,
        );
        // metadata filter
        if (criteria.matches(asset)) {
          searchResults.add(asset);
          _addedIds.add(assetId);
        }
      } catch (e) {
        debugPrint(
          "[SearchViewModel] Error fetching asset by ID '$assetId': $e",
        );
      }
    }
    _resolvedIdCount = assetIds.length;
  }

  Future<void> runFilenameSearch(String query) async {
    currentTextQuery = query;
    searchResults.clear();
    errorMessage = "";
    isSearching = true;
    notifyListeners();

    final int gen = ++_currentSearchIndex;
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

        if (gen != _currentSearchIndex) return;

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
      if (gen == _currentSearchIndex) {
        isSearching = false;
        notifyListeners();
      }
    }
  }

  /// Reset search state
  void clear() {
    currentTextQuery = "";
    searchResults.clear();
    errorMessage = "";
    isSearching = false;
    isLoadingMore = false;
    criteria = const FilterCriteria();
    _queryVector = null;
    _resolvedIdCount = 0;
    _resultLimit = _semanticPageSize;
    _addedIds.clear();
    hasMoreResults = false;
    _currentSearchIndex++;
    notifyListeners();
  }

  ImageProvider thumbnailProviderFor(String assetId) {
    return _mediaAssetRepo.thumbnailProviderFor(assetId);
  }
}
