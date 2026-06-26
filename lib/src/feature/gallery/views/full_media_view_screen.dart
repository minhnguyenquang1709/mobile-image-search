import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/src/core/constants/theme_constant.dart';
import 'package:mobile_image_search/src/core/constants/common_constant.dart';
import 'package:mobile_image_search/src/core/utils/media_processing.dart';
import 'package:mobile_image_search/src/core/utils/string.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:video_player/video_player.dart';

class MediaViewScreen extends StatefulWidget {
  final MediaAsset media;

  const MediaViewScreen({super.key, required this.media});

  @override
  State<MediaViewScreen> createState() => _MediaViewScreenState();
}

class _MediaViewScreenState extends State<MediaViewScreen> {
  bool isFocused = true;

  void _showMetadataSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => MediaMetadataSheet(media: widget.media),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.media.mediaType == EMediaType.video;
    return Scaffold(
      body: Flex(
        direction: Axis.vertical,
        children: [
          Expanded(
            child: GestureDetector(
              child: isVideo
                  ? VideoPlayerWidget(media: widget.media)
                  : ImageViewWidget(mediaAsset: widget.media),
              onTap: () {
                setState(() {
                  isFocused = !isFocused;
                });
              },
            ),
          ),
        ],
      ),
      appBar: !isFocused
          ? AppBar(
              backgroundColor: lightTheme.colorScheme.onPrimary,
              elevation: 4,
              titleSpacing: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back),
                color: lightTheme.colorScheme.primary,
                onPressed: () {
                  context.pop();
                },
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  color: lightTheme.colorScheme.primary,
                  onPressed: _showMetadataSheet,
                ),
              ],
            )
          : null,
      bottomNavigationBar: !isFocused
          ? BottomAppBar(child: Text(widget.media.title))
          : null,
      extendBody: true, // allow content to extend behind bottom navigation bar
      extendBodyBehindAppBar: true,
    );
  }
}

/// Bottom sheet showing basic metadata about a [MediaAsset]: file name,
/// format, resolution, file size and the album (folder) it lives in.
///
/// File size and album name are read from the [AssetEntity] (they are not
/// always carried on [MediaAsset]), so they load asynchronously.
class MediaMetadataSheet extends StatefulWidget {
  final MediaAsset media;

  const MediaMetadataSheet({super.key, required this.media});

  @override
  State<MediaMetadataSheet> createState() => _MediaMetadataSheetState();
}

class _MediaMetadataSheetState extends State<MediaMetadataSheet> {
  int? _sizeBytes;
  String? _albumName;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final assetEntity = await AssetEntity.fromId(widget.media.assetId);
    if (assetEntity == null) return;

    final file = await assetEntity.file;
    final size = await file?.length();

    // relativePath is like "DCIM/A/" — the album is the last folder segment.
    String? albumName;
    final relativePath = assetEntity.relativePath;
    if (relativePath != null && relativePath.isNotEmpty) {
      final segments = relativePath.split('/').where((s) => s.isNotEmpty);
      if (segments.isNotEmpty) albumName = segments.last;
    }

    if (!mounted) return;
    setState(() {
      _sizeBytes = size;
      _albumName = albumName;
    });
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildRow('File name', media.title),
            _buildRow('Format', media.format.name.toUpperCase()),
            _buildRow('Resolution', '${media.width} x ${media.height}'),
            _buildRow(
              'File size',
              _sizeBytes != null ? formatFileSize(_sizeBytes!) : '—',
            ),
            if (_albumName != null) _buildRow('Album', _albumName!),
          ],
        ),
      ),
    );
  }
}

class ImageViewWidget extends StatefulWidget {
  final MediaAsset mediaAsset;
  const ImageViewWidget({super.key, required this.mediaAsset});

  @override
  State<StatefulWidget> createState() => _ImageViewWidgetState();
}

class _ImageViewWidgetState extends State<ImageViewWidget> {
  late Future<AssetEntity?> _assetEntityFuture;

  @override
  void initState() {
    super.initState();

    _assetEntityFuture = AssetEntity.fromId(widget.mediaAsset.assetId);
  }

  @override
  void didUpdateWidget(covariant ImageViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldMediaMetadata = oldWidget.mediaAsset;
    final newMediaMetadata = widget.mediaAsset;
    if (!isSameMedia(oldMediaMetadata, newMediaMetadata)) {
      _assetEntityFuture = AssetEntity.fromId(widget.mediaAsset.assetId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _assetEntityFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Center(child: Text('Failed to load image'));
        }
        final assetEntity = snapshot.data!;
        return InteractiveViewer(
          constrained: true,
          maxScale: 4,
          child: AssetEntityImage(
            assetEntity,
            isOriginal: true,
            fit: BoxFit.contain,
            width: double.infinity,
          ),
        );
      },
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final MediaAsset media;

  const VideoPlayerWidget({super.key, required this.media});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  Timer? _loadVideoTimer;
  bool _isLoadingFailed = false;

  @override
  void initState() {
    super.initState();

    _loadVideoTimer = Timer(const Duration(seconds: 10), () {
      if (!_isInitialized) {
        setState(() {
          _isLoadingFailed = true;
        });
      }
    });
    try {
      final Future<AssetEntity?> assetEntityFuture = AssetEntity.fromId(
        widget.media.assetId,
      );
      assetEntityFuture.then((assetEntity) async {
        if (assetEntity == null) {
          throw Exception('Failed to load video asset');
        }
        final file = await assetEntity.file;
        if (file == null) {
          throw Exception('Failed to load video file');
        }
        _controller = VideoPlayerController.file(file)
          ..initialize().then((_) {
            setState(() {
              _isInitialized = true;
              _loadVideoTimer?.cancel();
              _isLoadingFailed = false;
            });
          });
      });
    } catch (e) {
      print('Error loading video: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingFailed) {
      return const Center(child: Text('Failed to load video'));
    }
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: SizedBox.expand(
        child: Stack(
          children: [
            // layer 1. video player with pinch to zoom
            InteractiveViewer(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
            ),

            // layer 2. playback controls
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              // video progress bar
                              SizedBox(
                                height: 30,
                                child: VideoProgressIndicator(
                                  _controller!,
                                  allowScrubbing: true, // seek by dragging
                                  colors: VideoProgressColors(
                                    playedColor: CustomColors.primary,
                                    backgroundColor: CustomColors.primary
                                        .withAlpha(140),
                                    bufferedColor: CustomColors.primary
                                        .withAlpha(0),
                                  ),
                                ),
                              ),

                              // video timestamp
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    formatVideoDuration(
                                      _controller!.value.duration.inSeconds,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          iconSize: 60,
                          icon: Icon(
                            _controller!.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            color: CustomColors.primary,
                          ),
                          onPressed: () {
                            setState(() {
                              _controller!.value.isPlaying
                                  ? _controller!.pause()
                                  : _controller!.play();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
