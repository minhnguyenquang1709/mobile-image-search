import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/core/config/theme.dart';
import 'package:mobile_image_search/core/constants/common_constant.dart';
import 'package:mobile_image_search/core/utils/media_processing.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:mobile_image_search/shared/domain/model/media.dart';
import 'package:video_player/video_player.dart';

class MediaViewScreen extends StatefulWidget {
  final Media media;

  const MediaViewScreen({super.key, required this.media});

  @override
  State<MediaViewScreen> createState() => _MediaViewScreenState();
}

class _MediaViewScreenState extends State<MediaViewScreen> {
  bool isFocused = true;

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.media.metadata.mediaType == EMediaType.video;
    return Scaffold(
      body: Flex(
        direction: Axis.vertical,
        children: [
          Expanded(
            child: GestureDetector(
              child: isVideo
                  ? VideoPlayerWidget(media: widget.media)
                  : ImageViewWidget(image: widget.media),
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
          ? BottomAppBar(child: Text(widget.media.metadata.name))
          : null,
      extendBody: true, // allow content to extend behind bottom navigation bar
      extendBodyBehindAppBar: true,
    );
  }
}

class ImageViewWidget extends StatefulWidget {
  final Media image;
  const ImageViewWidget({super.key, required this.image});

  @override
  State<StatefulWidget> createState() => _ImageViewWidgetState();
}

class _ImageViewWidgetState extends State<ImageViewWidget> {
  late Future<AssetEntity?> _assetEntityFuture;

  @override
  void initState() {
    super.initState();

    _assetEntityFuture = AssetEntity.fromId(widget.image.assetId);
  }

  @override
  void didUpdateWidget(covariant ImageViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldMediaMetadata = oldWidget.image.metadata;
    final newMediaMetadata = widget.image.metadata;
    if (!isSameMediaMetadata(oldMediaMetadata, newMediaMetadata)) {
      _assetEntityFuture = AssetEntity.fromId(widget.image.assetId);
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
  final Media media;

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

            // play/pause button
            SafeArea(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _controller!.value.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 48,
                        color: CustomColors.onPrimary,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
