import 'package:flutter/foundation.dart';
import 'package:objectbox/objectbox.dart';
// import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

@immutable
class TrashEntry {
  final String id;
  final String assetId;
  final DateTime trashedAt;

  const TrashEntry({
    required this.id,
    required this.assetId,
    required this.trashedAt,
  });
}

// @immutable
// class TrashItem {
//   final TrashEntry entry;
//   final MediaAsset asset;

//   const TrashItem({required this.entry, required this.asset});
// }

// @immutable
// class TrashState {
//   final List<TrashEntry> items;
//   final bool isLoading;
//   final Set<String> selectedAssetIds;

//   const TrashState({
//     required this.items,
//     this.isLoading = false,
//     this.selectedAssetIds = const {},
//   });

//   TrashState copyWith({
//     List<TrashEntry>? items,
//     bool? isLoading,
//     Set<String>? selectedAssetIds,
//   }) {
//     return TrashState(
//       items: items ?? this.items,
//       isLoading: isLoading ?? this.isLoading,
//       selectedAssetIds: selectedAssetIds ?? this.selectedAssetIds,
//     );
//   }
// }
