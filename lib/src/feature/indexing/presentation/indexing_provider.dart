// riverpod

import 'package:flutter_riverpod/flutter_riverpod.dart';

class IndexingState {}

final indexingProvider = StateProvider<IndexingState>((ref) {
  return IndexingState();
});
