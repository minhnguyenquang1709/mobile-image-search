import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/app_settings_controller.dart';
import 'package:mobile_image_search/src/constants/theme_constant.dart';
import 'package:mobile_image_search/src/feature/indexing/presentation/indexing_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appSettingsAsync = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text("Settings")),
      body: appSettingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text("Error loading settings: $error")),
        data: (data) {
          return ListView(
            addAutomaticKeepAlives: true,
            children: [
              if (data.totalToProcess > 0)
                Column(
                  children: [
                    // indexing status
                    Card(child: IndexingCard()),
                    Card(
                      child: ListTile(
                        title: const Text("Indexing Progress"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              color: CustomColors.primary,
                              backgroundColor: CustomColors.divider,
                              value: data.totalToProcess == 0
                                  ? null
                                  : data.processedCount / data.totalToProcess,
                            ),
                            Text(
                              "Processed ${data.processedCount} / ${data.totalToProcess}",
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Divider(),
                  ],
                ),

              // similarity threshold settings
              Card(
                child: ListTile(
                  title: const Text("Similarity Threshold"),
                  subtitle: Column(
                    children: [
                      const Text(
                        "The similarity score from which multiple images are considered the same.",
                      ),
                      Center(
                        child: Text(
                          data.searchSimilarityThreshold.toStringAsFixed(2),
                        ),
                      ),
                      Slider(
                        value: data.searchSimilarityThreshold,
                        onChanged: (value) {
                          // update in real time
                          ref
                              .read(appSettingsProvider.notifier)
                              .updateSearchSimilarityThreshold(value);
                        },
                        inactiveColor: CustomColors.onPrimary,
                        thumbColor: CustomColors.onPrimary,
                        activeColor: CustomColors.primary,
                      ),
                    ],
                  ),
                ),
              ),

              // auto categorization threshold settings
              // similarity threshold settings
              Card(
                child: ListTile(
                  title: const Text("Auto-Categorize Threshold"),
                  subtitle: Column(
                    children: [
                      const Text(
                        "The similarity score from which images are automatically put in the user-defined albums",
                      ),
                      Center(
                        child: Text(
                          data.autoCategorizationThreshold.toStringAsFixed(2),
                        ),
                      ),
                      Slider(
                        value: data.autoCategorizationThreshold,
                        onChanged: (value) {
                          // update in real time
                          ref
                              .read(appSettingsProvider.notifier)
                              .updateAutoCategorizationThreshold(value);
                        },
                        inactiveColor: CustomColors.onPrimary,
                        thumbColor: CustomColors.onPrimary,
                        activeColor: CustomColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
