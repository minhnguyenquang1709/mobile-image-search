import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  TranslationService._internal();

  factory TranslationService() {
    return _instance;
  }

  final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();
}
