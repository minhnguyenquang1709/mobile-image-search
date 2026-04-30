import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/gallery_controller.dart';
import 'package:mobile_image_search/src/utils/debug.dart';

class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({super.key});

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  String _albumName = "";

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          if (isDebugOrProfileMode)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    autocorrect: false,
                    onChanged: (value) {
                      setState(() {
                        _albumName = value;
                      });
                    },
                  ),
                ),
                // submit button
                IconButton(
                  icon: const Icon(Icons.photo_album),
                  onPressed: () {
                    ref
                        .read(galleryControllerProvider.notifier)
                        .createAlbum(_albumName);
                  },
                ),
              ],
            ),
          Row(
            children: [
              TextButton(
                child: Text("Move to Trash"),
                onPressed: () {
                  ref.read(galleryControllerProvider.notifier).moveToTrash();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
