import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/src/core/constants/theme_constant.dart';
import 'package:mobile_image_search/src/core/constants/common_constant.dart';
import 'package:mobile_image_search/src/core/utils/string.dart';
import 'package:mobile_image_search/src/feature/gallery/viewmodels/media_view_viewmodel.dart';
import 'package:mobile_image_search/src/service_locator.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';
import 'package:video_player/video_player.dart';

class MediaViewScreen extends StatefulWidget {
  final MediaAsset media;

  const MediaViewScreen({super.key, required this.media});

  @override
  State<MediaViewScreen> createState() => _MediaViewScreenState();
}

class _MediaViewScreenState extends State<MediaViewScreen> {
  final MediaViewModel _mediaVM = MediaViewModel(
    mediaAssetRepo: ServiceLocator.mediaAssetRepository,
  );
  bool isFocused = true;

  @override
  void initState() {
    super.initState();
    _mediaVM.load(widget.media);
  }

  @override
  void dispose() {
    _mediaVM.dispose();
    super.dispose();
  }

  void _showMetadataSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) =>
          MediaMetadataSheet(viewModel: _mediaVM, media: widget.media),
    );
  }

  Widget _buildContent() {
    final isVideo = widget.media.mediaType == EMediaType.video;

    if (_mediaVM.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_mediaVM.hasError) {
      return Center(
        child: Text('Failed to load ${isVideo ? 'video' : 'image'}'),
      );
    }

    if (isVideo) {
      final file = _mediaVM.videoFile;
      if (file == null) {
        return const Center(child: Text('Failed to load video'));
      }
      return VideoPlayerWidget(file: file);
    }

    final provider = _mediaVM.imageProvider;
    if (provider == null) {
      return const Center(child: Text('Failed to load image'));
    }
    return ImageViewWidget(provider: provider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Flex(
        direction: Axis.vertical,
        children: [
          Expanded(
            child: GestureDetector(
              child: ListenableBuilder(
                listenable: _mediaVM,
                builder: (context, _) => _buildContent(),
              ),
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

class MediaMetadataSheet extends StatefulWidget {
  final MediaViewModel viewModel;
  final MediaAsset media;

  const MediaMetadataSheet({
    super.key,
    required this.viewModel,
    required this.media,
  });

  @override
  State<MediaMetadataSheet> createState() => _MediaMetadataSheetState();
}

class _MediaMetadataSheetState extends State<MediaMetadataSheet> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.loadDetails(widget.media);
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
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) {
            final details = widget.viewModel.details;
            return Column(
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
                  details?.sizeBytes != null
                      ? formatFileSize(details!.sizeBytes!)
                      : '-',
                ),
                if (details?.albumName != null)
                  _buildRow('Album', details!.albumName!),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ImageViewWidget extends StatelessWidget {
  final ImageProvider provider;

  const ImageViewWidget({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      constrained: true,
      maxScale: 4,
      child: Image(
        image: provider,
        fit: BoxFit.contain,
        width: double.infinity,
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final File file;

  const VideoPlayerWidget({super.key, required this.file});

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

    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
          _loadVideoTimer?.cancel();
          _isLoadingFailed = false;
        });
      });
  }

  @override
  void dispose() {
    _loadVideoTimer?.cancel();
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
