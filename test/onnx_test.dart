import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ONNX Runtime smoke test', () async {
    final ort = OnnxRuntime();
    final providers = await ort.getAvailableProviders();
    print('Available ONNX Runtime providers: $providers');
    expect(providers, isNotEmpty);
  });
}
