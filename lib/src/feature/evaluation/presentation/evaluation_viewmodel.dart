import 'package:flutter/foundation.dart';
import 'package:mobile_image_search/src/feature/evaluation/data/evaluation_service.dart';
import 'package:mobile_image_search/src/feature/evaluation/domain/eval_progress.dart';
import 'package:mobile_image_search/src/feature/evaluation/domain/evaluation_report.dart';

/// ViewModel for the model-evaluation screen.
class EvaluationViewModel extends ChangeNotifier {
  final EvaluationService _service;

  EvaluationViewModel({required EvaluationService service})
    : _service = service;

  EvalProgress progress = const EvalProgress();
  EvaluationReport? report;
  String? error;
  bool isRunning = false;

  String? get reportPath => _service.lastReportPath;

  Future<void> runEvaluation(String datasetDir) async {
    if (isRunning) return;

    isRunning = true;
    error = null;
    report = null;
    progress = const EvalProgress(phase: EvalPhase.loading);
    notifyListeners();

    try {
      report = await _service.run(
        datasetDir,
        onProgress: (p) {
          progress = p;
          notifyListeners();
        },
      );
    } catch (e) {
      error = "$e";
      progress = progress.copyWith(phase: EvalPhase.error);
      debugPrint("[EvaluationViewModel] Evaluation failed: $e");
    } finally {
      isRunning = false;
      notifyListeners();
    }
  }
}
