class EmptyQueryException implements Exception {
  final String cause;

  EmptyQueryException(this.cause);
}

class MediaAssetNotFoundException implements Exception {
  final String assetId;

  MediaAssetNotFoundException(this.assetId);
}

class OutOfVocabularyException implements Exception {
  final String word;

  OutOfVocabularyException(this.word);
}

class QueryTooLongException implements Exception {
  final int tokenCount;
  final int maxTokenCount;

  QueryTooLongException(this.tokenCount, this.maxTokenCount);
}
