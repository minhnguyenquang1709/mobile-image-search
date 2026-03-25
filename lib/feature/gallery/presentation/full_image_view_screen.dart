import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/core/config/theme.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:mobile_image_search/shared/domain/image_model.dart'
    as image_model;
import 'package:video_player/video_player.dart';

class MediaViewScreen extends StatefulWidget {
  final image_model.Image image;

  const MediaViewScreen({super.key, required this.image});

  @override
  State<MediaViewScreen> createState() => _MediaViewScreenState();
}

class _MediaViewScreenState extends State<MediaViewScreen> {
  bool isFocused = true;

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.image.assetEntity.type == AssetType.video;
    return Scaffold(
      body: Flex(
        direction: Axis.vertical,
        children: [
          Expanded(
            child: GestureDetector(
              child: InteractiveViewer(
                constrained: true,
                maxScale: 4.0,
                child: isVideo
                    ? VideoPlayerWidget(video: widget.image)
                    : ImageContainer(image: widget.image),
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
            )
          : null,
      bottomNavigationBar: !isFocused
          ? BottomAppBar(child: Text(widget.image.metadata.name))
          : null,
      extendBody: true, // allow content to extend behind bottom navigation bar
      extendBodyBehindAppBar: true,
    );
  }
}

class ImageContainer extends StatelessWidget {
  final image_model.Image image;
  const ImageContainer({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    return AssetEntityImage(
      image.assetEntity,
      isOriginal: true,
      fit: BoxFit.contain,
      width: double.infinity,
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final image_model.Image video;

  const VideoPlayerWidget({super.key, required this.video});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    widget.video.assetEntity.file.then((value) {
      if (value == null) {
        throw Exception('Failed to load video file');
      }
      _controller = VideoPlayerController.file(value)
        ..initialize().then((_) {
          setState(() {
            _isInitialized = true;
          });
          _controller.play();
        });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isInitialized
        ? SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          )
        : const Center(child: CircularProgressIndicator());
  }
}
