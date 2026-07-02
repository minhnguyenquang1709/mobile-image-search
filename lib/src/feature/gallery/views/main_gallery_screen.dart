import 'package:flutter/material.dart';
import 'package:mobile_image_search/src/feature/gallery/viewmodels/selection_viewmodel.dart';
import 'package:mobile_image_search/src/feature/gallery/views/gallery_view.dart';
import 'package:mobile_image_search/src/feature/gallery/views/selection_app_bar.dart';
import 'package:mobile_image_search/src/feature/search/domain/filter_criteria.dart';
import 'package:mobile_image_search/src/feature/search/viewmodels/image_search_viewmodel.dart';
import 'package:mobile_image_search/src/feature/search/views/filter_sheet.dart';
import 'package:mobile_image_search/src/feature/search/views/search_grid_view.dart';
import 'package:mobile_image_search/src/service_locator.dart';

/// Shows the gallery, and swaps in the search grid when the user runs a search
class MainGalleryScreen extends StatefulWidget {
  const MainGalleryScreen({super.key});

  @override
  State<MainGalleryScreen> createState() => _MainGalleryScreenState();
}

class _MainGalleryScreenState extends State<MainGalleryScreen> {
  final TextEditingController _searchTextController = TextEditingController();

  final SearchViewModel _searchVM = ServiceLocator.searchViewModel;

  // Gallery/Search view switch
  bool _isSearching = false;

  @override
  void dispose() {
    _searchTextController.dispose();
    super.dispose();
  }

  // Search view is shown when there is a query OR any active filter.
  bool _shouldShowSearch() =>
      _searchTextController.text.trim().isNotEmpty ||
      _searchVM.criteria.isActive;

  void _performSearch(String query) {
    FocusScope.of(context).unfocus();
    setState(() => _isSearching = _shouldShowSearch());

    if (_searchVM.mode == SearchMode.semantic) {
      // semantic search needs a phrase
      if (query.trim().isEmpty) return;
      _searchVM.searchByEnglishPhrase(query);
    } else {
      // filename search runs even with an empty query (lists all matching filters)
      _searchVM.runFilenameSearch(query);
    }
  }

  void _toggleMode() {
    final SearchMode next = _searchVM.mode == SearchMode.semantic
        ? SearchMode.filename
        : SearchMode.semantic;
    _searchVM.setMode(next);
    setState(() {});
  }

  Future<void> _openFilterSheet() async {
    final FilterCriteria? result = await showModalBottomSheet<FilterCriteria>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FilterSheet(initial: _searchVM.criteria),
    );
    if (result == null) return;

    _searchVM.setCriteria(result);
    setState(() => _isSearching = _shouldShowSearch());
  }

  void _clearSearch() {
    _searchTextController.clear();
    _searchVM.clear();
    setState(() => _isSearching = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool isFilenameMode = _searchVM.mode == SearchMode.filename;
    final SelectionViewModel selectionVM = ServiceLocator.selectionViewModel;

    return ListenableBuilder(
      listenable: selectionVM,
      builder: (context, _) {
        return Scaffold(
          // morph to "N selected" + Cancel while selecting
          appBar: selectionVM.isActive ? const SelectionAppBar() : null,
          body: Stack(
            children: [
              // Body swaps between the gallery and the search results.
              Positioned.fill(
                child: _isSearching
                    ? const SearchGridView()
                    : const GalleryView(),
              ),

              // Persistent search bar chrome - hidden during selection.
              if (!selectionVM.isActive)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(38),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Mode toggle (semantic <-> filename)
                        IconButton(
                          icon: Icon(
                            isFilenameMode
                                ? Icons.text_fields
                                : Icons.auto_awesome,
                            color: Colors.grey,
                          ),
                          tooltip: isFilenameMode
                              ? "Search mode: Filename"
                              : "Search mode: Semantic",
                          onPressed: _toggleMode,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _searchTextController,
                            decoration: InputDecoration(
                              hintText: isFilenameMode
                                  ? "Search by file name"
                                  : "Search with an English phrase",
                              border: InputBorder.none,
                              hintStyle: const TextStyle(color: Colors.grey),
                            ),
                            onSubmitted: _performSearch,
                          ),
                        ),
                        // Filter sheet
                        IconButton(
                          icon: const Icon(Icons.filter_list),
                          color: _searchVM.criteria.isActive
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                          tooltip: "Filters",
                          onPressed: _openFilterSheet,
                        ),
                        if (_isSearching)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: () =>
                              _performSearch(_searchTextController.text),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
