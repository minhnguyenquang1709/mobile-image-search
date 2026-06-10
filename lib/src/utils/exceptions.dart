class EmptyQueryException implements Exception {
  final String cause;

  EmptyQueryException(this.cause);
}
