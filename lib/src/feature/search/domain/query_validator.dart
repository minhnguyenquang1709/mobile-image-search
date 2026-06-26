import 'package:mobile_image_search/src/domain/bpe_tokenizer.dart';
import 'package:mobile_image_search/src/core/utils/exceptions.dart';

class QueryValidator {
  final BpeTokenizer _bpeTokenizer;

  QueryValidator({required BpeTokenizer bpeTokenizer})
    : _bpeTokenizer = bpeTokenizer;

  /// Validates [text] before it is sent for embedding.
  ///
  /// Steps:
  /// 1. Trim & normalize whitespace. Throw [EmptyQueryException] if blank.
  /// 2. For each word, apply BPE and check that every resulting subword exists
  ///    in the vocabulary. Throw [OutOfVocabularyException] on the first unknown word.
  /// 3. Tokenize the full query. Throw [QueryTooLongException] if the token
  ///    count (excluding start/end/padding) exceeds the model's context length.
  void validate(String text) {
    // 1. empty check
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) {
      throw EmptyQueryException('Search query must not be empty.');
    }

    final words = normalized.split(' ');

    // 2. OOV check — each word is split into BPE subwords; every subword must
    //    exist in the vocabulary (mirrors what tokenizeText does internally)
    for (final word in words) {
      final subWords = _bpeTokenizer.applyBPE(word);
      final hasUnknown = subWords.any((sw) => !_bpeTokenizer.isInVocab(sw));
      if (hasUnknown) {
        throw OutOfVocabularyException(word);
      }
    }

    // 3. token length check
    // tokenizeText produces contextLength tokens total (start + content + end + padding).
    // Count only meaningful payload tokens (exclude start, end, and padding).
    final tokens = _bpeTokenizer.tokenizeText(normalized);
    final meaningfulCount = tokens
        .skip(1) // skip start token
        .takeWhile(
          (id) =>
              id != BpeTokenizer.endTokenId && id != BpeTokenizer.padTokenId,
        )
        .length;

    final maxPayload = BpeTokenizer.contextLength - 2; // -2 for start + end
    if (meaningfulCount > maxPayload) {
      throw QueryTooLongException(meaningfulCount, maxPayload);
    }
  }
}
