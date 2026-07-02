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

    // split into words, dropping punctuation stuck to their edges (e.g. "cat,")
    final words = normalized
        .split(' ')
        .map((w) => w.replaceAll(RegExp(r'^[^a-z0-9]+|[^a-z0-9]+$'), ''))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      throw EmptyQueryException('Search query must not be empty.');
    }

    // 2. OOV check, BPE can encode any string into in-vocab subwords, so
    //    checking subwords never catches gibberish ("abc", "wrefwertyhju6r").
    for (final word in words) {
      if (!_isRecognizedWord(word)) {
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

  /// Whether [word] looks like a real word rather than gibberish.
  ///
  /// Common words are a single whole-word vocab token (`dog</w>`). Longer real
  /// words split into a few multi-character subwords ("operation" -> "oper",
  /// "ation"), while gibberish fragments down to single characters, so
  /// reject only when a subword is a lone character.
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
