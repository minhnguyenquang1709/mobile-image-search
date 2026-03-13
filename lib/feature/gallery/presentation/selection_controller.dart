import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectionController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return <String>{};
  }

  void selectImage(String assetId) {
    state = {...state, assetId};

    // TODO: remove debug
    print("Selected asset IDs: $state");
  }

  void deselectImage(String assetId) {
    if (_isImageSelected(assetId)) {
      state = state.where((id) => id != assetId).toSet();
    }

    // TODO: remove debug
    print("Selected asset IDs: $state");
  }

  bool _isImageSelected(String assetId) {
    return state.contains(assetId);
  }
}

final selectionControllerProvider =
    NotifierProvider<SelectionController, Set<String>>(
      () => SelectionController(),
    );
