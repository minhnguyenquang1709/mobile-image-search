import 'package:flutter/material.dart';
import 'package:mobile_image_search/src/core/constants/theme_constant.dart';
import 'package:mobile_image_search/src/feature/indexing/presentation/indexing_viewmodel.dart';
import 'package:mobile_image_search/src/shared/domain/model/indexing_progress.dart';

class IndexingCard extends StatefulWidget {
  const IndexingCard({super.key});

  @override
  State<IndexingCard> createState() => _IndexingCardState();
}

class _IndexingCardState extends State<IndexingCard> {
  final IndexingViewModel _vm = IndexingViewModel.instance;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final progress = _vm.currentProgress;

        if (progress.isIndexing &&
            progress.phase == EIndexingPhase.fetchingMedia) {
          return _buildCard("Fetching gallery media…");
        }

        if (progress.isIndexing && progress.phase == EIndexingPhase.diffing) {
          return _buildCard("Comparing with existing index…");
        }

        final processed = progress.processed;
        final total = progress.total;
        if (processed == 0 && total == 0) {
          return const SizedBox.shrink();
        }

        return _buildCard(
          "Processed $processed / $total",
          value: total == 0 ? null : processed / total,
        );
      },
    );
  }

  Widget _buildCard(String status, {double? value}) {
    return Card(
      child: ListTile(
        title: const Text("Indexing Progress"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status),
            LinearProgressIndicator(
              color: CustomColors.primary,
              backgroundColor: CustomColors.divider,
              value: value,
            ),
          ],
        ),
      ),
    );
  }
}
