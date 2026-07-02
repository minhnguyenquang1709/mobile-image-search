import 'package:flutter/foundation.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

/// App-wide multi-select state, shared by the gallery grid and opened albums.
class SelectionViewModel extends ChangeNotifier {
  final Set<MediaAsset> _selected = {};

  Set<MediaAsset> get selected => Set.unmodifiable(_selected);
  bool get isActive => _selected.isNotEmpty;
  int get count => _selected.length;

  // Compare by assetId, MediaAsset has no == and album pages refetch new instances.
  bool isSelected(MediaAsset asset) =>
      _selected.any((m) => m.assetId == asset.assetId);

  void toggle(MediaAsset asset) {
    if (isSelected(asset)) {
      deselect(asset);
    } else {
      select(asset);
    }
  }

  void select(MediaAsset asset) {
    if (isSelected(asset)) return;
    _selected.add(asset);
    notifyListeners();
  }

  void deselect(MediaAsset asset) {
    _selected.removeWhere((m) => m.assetId == asset.assetId);
    notifyListeners();
  }

  void clear() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }
}
