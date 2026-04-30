import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/src/constants/theme_constant.dart';
import 'package:mobile_image_search/src/constants/common_constant.dart';
import 'package:mobile_image_search/src/utils/media_processing.dart';
import 'package:mobile_image_search/src/utils/string.dart';
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
