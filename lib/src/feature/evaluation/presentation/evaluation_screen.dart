import 'package:flutter/material.dart';
import 'package:mobile_image_search/src/feature/evaluation/domain/eval_progress.dart';
import 'package:mobile_image_search/src/feature/evaluation/domain/evaluation_report.dart';
import 'package:mobile_image_search/src/feature/evaluation/presentation/evaluation_viewmodel.dart';
import 'package:mobile_image_search/src/service_locator.dart';
import 'package:path_provider/path_provider.dart';

class EvaluationScreen extends StatefulWidget {
  const EvaluationScreen({super.key});

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  final EvaluationViewModel _vm = ServiceLocator.evaluationViewModel;
  final TextEditingController _pathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prefillDefaultPath();
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _prefillDefaultPath() async {
    final dir = await getExternalStorageDirectory();
    if (dir != null && _pathController.text.isEmpty) {
      _pathController.text = dir.path;
    }
  }

  String _phaseLabel(EvalProgress p) {
    switch (p.phase) {
      case EvalPhase.idle:
        return 'Idle';
      case EvalPhase.loading:
        return 'Loading dataset…';
      case EvalPhase.indexing:
        return 'Indexing ${p.current}/${p.total}';
      case EvalPhase.loadingEmbeddings:
        return 'Loading embeddings…';
      case EvalPhase.searching:
        return 'Searching ${p.current}/${p.total}';
      case EvalPhase.done:
        return 'Done';
      case EvalPhase.error:
        return 'Error';
    }
  }

  String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Model Evaluation')),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _pathController,
                    decoration: const InputDecoration(
                      labelText: 'Dataset folder (contains ground_truth.json)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _vm.isRunning
                        ? null
                        : () => _vm.runEvaluation(_pathController.text.trim()),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Run evaluation'),
                  ),
                  const SizedBox(height: 16),

                  if (_vm.isRunning) _buildProgress(),
                  if (_vm.error != null)
                    Text(_vm.error!, style: const TextStyle(color: Colors.red)),
                  if (_vm.report != null) _buildReport(_vm.report!),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgress() {
    final EvalProgress p = _vm.progress;
    final double? value = p.total > 0 ? p.current / p.total : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_phaseLabel(p)),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: value),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildReport(EvaluationReport r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Results - ${r.datasetName}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text('${r.imageCount} images, ${r.queryCount} queries'),
        const SizedBox(height: 12),

        _summaryTable(r),
        const SizedBox(height: 16),

        const Text('Per-query', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _perQueryTable(r),

        const SizedBox(height: 16),
        if (_vm.reportPath != null)
          Text(
            'Report exported to:\n${_vm.reportPath}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
      ],
    );
  }

  Widget _summaryTable(EvaluationReport r) {
    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Column(
      children: [
        row('Mean R@1', r.meanRecallAt1.toStringAsFixed(3)),
        row('Mean R@5', r.meanRecallAt5.toStringAsFixed(3)),
        row('Mean R@10', r.meanRecallAt10.toStringAsFixed(3)),
        row('MRR', r.mrr.toStringAsFixed(3)),
        const Divider(),
        row('Indexing total', '${r.totalIndexingMs} ms'),
        row(
          'Indexing / image',
          '${r.meanIndexingMsPerImage.toStringAsFixed(1)} ms',
        ),
        row('Embedding load', '${r.embeddingLoadMs} ms'),
        row('First query warmup', '${r.firstQueryWarmupMs} ms'),
        row('Search total', '${r.totalSearchMs} ms'),
        row(
          'Search / query',
          '${r.meanSearchMsPerQuery.toStringAsFixed(1)} ms',
        ),
        row('  ↳ encode text', '${r.meanEncodeTextMs.toStringAsFixed(1)} ms'),
        row('  ↳ ANN query', '${r.meanAnnQueryMs.toStringAsFixed(1)} ms'),
        const Divider(),
        row('Model size', _mb(r.modelSizeBytes)),
        row('Vector store size', _mb(r.vectorStoreSizeBytes)),
        row('Peak RAM (indexing)', _mb(r.peakRssIndexingBytes)),
        row('Peak RAM (search)', _mb(r.peakRssSearchBytes)),
      ],
    );
  }

  Widget _perQueryTable(EvaluationReport r) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Query')),
          DataColumn(label: Text('R@1')),
          DataColumn(label: Text('R@5')),
          DataColumn(label: Text('R@10')),
          DataColumn(label: Text('RR')),
          DataColumn(label: Text('1st hit')),
        ],
        rows: [
          for (final q in r.perQuery)
            DataRow(
              cells: [
                DataCell(Text(q.query)),
                DataCell(Text(q.r1.toStringAsFixed(2))),
                DataCell(Text(q.r5.toStringAsFixed(2))),
                DataCell(Text(q.r10.toStringAsFixed(2))),
                DataCell(Text(q.rr.toStringAsFixed(2))),
                DataCell(Text(q.firstHitRank == 0 ? '—' : '${q.firstHitRank}')),
              ],
            ),
        ],
      ),
    );
  }
}
