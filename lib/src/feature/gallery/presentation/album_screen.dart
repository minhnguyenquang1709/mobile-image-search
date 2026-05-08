import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_image_search/src/constants/route_constant.dart';
import 'package:mobile_image_search/src/feature/gallery/presentation/album_controller.dart';
import 'package:mobile_image_search/src/shared/domain/model/album.dart';

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
    final albumController = ref.watch(albumControllerProvider);
    return Container(
      child: albumController.when(
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stackTrace) {
          return Center(child: const Text("Error loading albums"));
        },
        data: (List<Album> albumList) {
          if (albumList.isEmpty) {
            return const Center(child: const Text("No albums found"));
          }

          return ListView(
            children: [
              for (final album in albumList)
                ListTile(
                  title: Text(album.title),
                  subtitle: Text("ID: ${album.id}"),
                  onTap: () {
                    debugPrint("Tapped on album: ${album.title}");

                    context.push(
                      RouteConstants.albumView,
                      extra: {'album': album},
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
