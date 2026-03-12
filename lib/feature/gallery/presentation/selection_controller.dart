import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectionController extends Notifier<Set<String>> {
  final Set<String> _selectedAssetIds = {};

  @override
  Set<String> build() {
    return _selectedAssetIds;
  }

  void toggleSelection(String assetId) {
    if (_selectedAssetIds.contains(assetId)) {
      _selectedAssetIds.remove(assetId);
    } else {
      _selectedAssetIds.add(assetId);
    }
    state = Set.from(_selectedAssetIds); // Trigger state update

    // TODO: remove debug
    print("Selected asset IDs: $state");
  }

  bool isSelected(String assetId) {
    return _selectedAssetIds.contains(assetId);
  }
}

final selectionControllerProvider =
    NotifierProvider<SelectionController, Set<String>>(
      () => SelectionController(),
    );
