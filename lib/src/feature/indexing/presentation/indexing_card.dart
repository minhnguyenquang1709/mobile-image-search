import 'package:flutter/material.dart';
import 'package:mobile_image_search/src/core/constants/theme_constant.dart';
import 'package:mobile_image_search/src/feature/indexing/presentation/indexing_viewmodel.dart';

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
        final processed = _vm.currentProgress.processed;
        final total = _vm.currentProgress.total;
        if (processed == 0 && total == 0) {
          return const SizedBox.shrink();
        }

        return Card(
          child: ListTile(
            title: const Text("Indexing Progress"),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Processed $processed / $total"),
                LinearProgressIndicator(
                  color: CustomColors.primary,
                  backgroundColor: CustomColors.divider,
                  value: total == 0 ? null : processed / total,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
