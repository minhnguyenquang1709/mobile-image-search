import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/common_widgets/image_widget.dart';
import 'package:mobile_image_search/src/constants/config_constant.dart';
import 'package:mobile_image_search/src/constants/theme_constant.dart';
import 'package:mobile_image_search/src/feature/search/domain/model/search_result.dart';
import 'package:mobile_image_search/src/feature/search/presentation/image_search_controller.dart';

class ImageSearchScreen extends ConsumerStatefulWidget {
  const ImageSearchScreen({super.key});

  @override
  ConsumerState<ImageSearchScreen> createState() => _ImageSearchScreenState();
}

class _ImageSearchScreenState extends ConsumerState<ImageSearchScreen> {
  String _searchQuery = "";

  void _updateSearchQuery(String query) {
    ref.read(imageSearchController.notifier).updateSearchQuery(query);
  }

  void _searchByCaption() {
    ref.read(imageSearchController.notifier).searchByCaption();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Image Search")),
      body: SafeArea(
        child: Column(
          children: [
            // search result
            const Expanded(child: SearchResultWidget()),

            // search bar
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // text field with expanded to prevent box with no size exception
                  Expanded(
                    child: TextField(
                      showCursor: true,
                      autocorrect: false,
                      autofocus: true,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      // run on enter key press
                      onSubmitted: (_) => _searchByCaption(),
                      decoration: const InputDecoration(
                        hintText: "Describe the image...",
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    iconSize: UIConfig.searchButtonIconHeight,
                    icon: Icon(Icons.search, color: CustomColors.primary),
                    onPressed: () {
                      _updateSearchQuery(_searchQuery);
                      _searchByCaption();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Build sliver list of search results
class SearchResultWidget extends ConsumerStatefulWidget {
  const SearchResultWidget({super.key});

  @override
  ConsumerState<SearchResultWidget> createState() => _SearchResultWidgetState();
}

class _SearchResultWidgetState extends ConsumerState<SearchResultWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 500) {
        // scroll to top button logic if needed
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageSearchControllerAsync = ref.watch(imageSearchController);

    return Container(
      child: imageSearchControllerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text("Error loading search results: $error")),
        data: (List<SearchResultMatch> resultItems) {
          if (ref.read(imageSearchController.notifier).searchQuery.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Describe the image you want to find"),
                  SizedBox(height: 8),
                  Text("Example: \"white cat\""),
                ],
              ),
            );
          }
          if (resultItems.isEmpty) {
            return const Center(child: Text("No results found"));
          }

          // build list of search results with similarity scores
          return RawScrollbar(
            controller: _scrollController,
            child: CustomScrollView(
              slivers: [
                SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: UIConfig.imagesPerRow,
                    mainAxisSpacing: UIConfig.crossAxisSpacing,
                    crossAxisSpacing: UIConfig.mainAxisSpacing,
                  ),
                  itemBuilder: (context, index) {
                    final resultItem = resultItems[index];
                    return SearchResultThumbnailWidget(resultItem: resultItem);
                  },
                  itemCount: resultItems.length,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Thumbnail widget with similarity score badge
class SearchResultThumbnailWidget extends StatelessWidget {
  final SearchResultMatch resultItem;

  const SearchResultThumbnailWidget({super.key, required this.resultItem});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Image
        ThumbnailWidget(assetId: resultItem.assetId),

        // Similarity score badge
        Positioned(
          top: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              resultItem.cosineScore.toStringAsFixed(2),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
