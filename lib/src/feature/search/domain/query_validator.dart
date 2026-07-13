import 'package:mobile_image_search/src/domain/bpe_tokenizer.dart';
import 'package:mobile_image_search/src/core/utils/exceptions.dart';

class QueryValidator {
  final BpeTokenizer _bpeTokenizer;

  QueryValidator({required BpeTokenizer bpeTokenizer})
    : _bpeTokenizer = bpeTokenizer;

  /// Validates [text] before it is sent for embedding.
  void validate(String text) {
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) {
      throw EmptyQueryException('Search query must not be empty.');
    }

    // split into words, dropping punctuation stuck to their edges
    final words = normalized
        .split(' ')
        .map((w) => w.replaceAll(RegExp(r'^[^a-z0-9]+|[^a-z0-9]+$'), ''))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      throw EmptyQueryException('Search query must not be empty.');
    }

    for (final word in words) {
      if (!_isRecognizedWord(word)) {
        throw OutOfVocabularyException(word);
      }
    }

    final tokens = _bpeTokenizer.tokenizeText(normalized);
    final meaningfulCount = tokens
        .skip(1) // skip start token
        .takeWhile(
          (id) =>
              id != BpeTokenizer.endTokenId && id != BpeTokenizer.padTokenId,
        )
        .length;

    final maxPayload = BpeTokenizer.contextLength - 2; // [start], [end] tokens
    if (meaningfulCount > maxPayload) {
      throw QueryTooLongException(meaningfulCount, maxPayload);
    }
  }

  bool _isRecognizedWord(String word) {
    if (_bpeTokenizer.isInVocab('$word</w>')) return true;

    final subWords = _bpeTokenizer.applyBPE(word);
    for (final sw in subWords) {
      final core = sw.replaceAll('</w>', '');
      if (core.length < 2) return false;
    }
    return true;
  }
}
