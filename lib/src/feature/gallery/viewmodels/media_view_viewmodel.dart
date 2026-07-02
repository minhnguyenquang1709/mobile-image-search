import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:mobile_image_search/src/core/constants/common_constant.dart';
import 'package:mobile_image_search/src/data/interfaces/media_asset_repository_interface.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_details.dart';

/// Display full-screen media
class MediaViewModel extends ChangeNotifier {
  final IMediaAssetRepository _mediaAssetRepo;

  MediaViewModel({required IMediaAssetRepository mediaAssetRepo})
    : _mediaAssetRepo = mediaAssetRepo;

  ImageProvider? _imageProvider;
  ImageProvider? get imageProvider => _imageProvider;

  File? _videoFile;
  File? get videoFile => _videoFile;

  MediaDetails? _details;
  MediaDetails? get details => _details;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasError = false;
  bool get hasError => _hasError;

  Future<void> load(MediaAsset media) async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      if (media.mediaType == EMediaType.video) {
        _videoFile = await _mediaAssetRepo.getVideoFile(media.assetId);
      } else {
        _imageProvider = await _mediaAssetRepo.fullResolutionProviderFor(
          media.assetId,
        );
      }
    } catch (e) {
      _hasError = true;
      debugPrint("[MediaViewModel] Error loading media: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDetails(MediaAsset media) async {
    try {
      _details = await _mediaAssetRepo.getMediaDetails(media.assetId);
      notifyListeners();
    } catch (e) {
      debugPrint("[MediaViewModel] Error loading details: $e");
    }
  }
}
