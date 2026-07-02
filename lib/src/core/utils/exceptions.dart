class EmptyQueryException implements Exception {
  final String cause;

  EmptyQueryException(this.cause);

  @override
  String toString() => cause;
}

class MediaAssetNotFoundException implements Exception {
  final String assetId;

  MediaAssetNotFoundException(this.assetId);
}

class OutOfVocabularyException implements Exception {
  final String word;

  OutOfVocabularyException(this.word);

  @override
  String toString() => '"$word" is not a recognized English word.';
}

class QueryTooLongException implements Exception {
  final int tokenCount;
  final int maxTokenCount;

  QueryTooLongException(this.tokenCount, this.maxTokenCount);

  @override
  String toString() => 'Your search phrase is too long.';
}

class InvalidAlbumNameException implements Exception {
  final String message;

  InvalidAlbumNameException(this.message);

  @override
  String toString() => message;
}
