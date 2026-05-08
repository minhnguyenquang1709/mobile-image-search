import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

class SelectionController extends Notifier<Set<MediaAsset>> {
  @override
  Set<MediaAsset> build() {
    return <MediaAsset>{};
  }

  void selectMedia(MediaAsset mediaAsset) {
    state = {...state, mediaAsset};
  }

  void deselectMedia(MediaAsset mediaAsset) {
    if (_isMediaAssetSelected(mediaAsset)) {
      state = state.where((id) => id != mediaAsset).toSet();
    }
  }

  bool _isMediaAssetSelected(MediaAsset mediaAsset) {
    return state.contains(mediaAsset);
  }

  void clearSelection() {
    state = <MediaAsset>{};
  }
}

final homeScreenSelectionControllerProvider =
    NotifierProvider<SelectionController, Set<MediaAsset>>(
      () => SelectionController(),
    );

final albumScreenSelectionControllerProvider =
    NotifierProvider<SelectionController, Set<MediaAsset>>(
      () => SelectionController(),
    );
