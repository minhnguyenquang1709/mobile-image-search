import 'package:flutter/material.dart';
import 'package:mobile_image_search/src/core/constants/theme_constant.dart';
import 'package:mobile_image_search/src/core/utils/string.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

class ThumbnailWidget extends StatefulWidget {
  final MediaAsset mediaAsset;
  final ImageProvider provider;
  final Function? onTap;
  final Function? onLongPress;

  const ThumbnailWidget({
    super.key,
    required this.mediaAsset,
    required this.provider,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<ThumbnailWidget> createState() => _ThumbnailWidgetState();
}

class _ThumbnailWidgetState extends State<ThumbnailWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final MediaAsset mediaAsset = widget.mediaAsset;

        return GestureDetector(
          onTap: () {
            if (widget.onTap != null) widget.onTap!(mediaAsset);
          },
          onLongPress: () {
            if (widget.onLongPress != null) widget.onLongPress!();
          },
          child: RepaintBoundary(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image(image: widget.provider, fit: BoxFit.cover),
                ),

                if (mediaAsset is VideoAsset && mediaAsset.duration > 0)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.only(left: 5, right: 5),
                      decoration: BoxDecoration(
                        color: CustomColors.surface.withAlpha(200),
                        borderRadius: BorderRadius.circular(99.0),
                      ),
                      child: SizedBox.fromSize(
                        size: const Size(40, 20),
                        child: Center(
                          child: Text(
                            formatVideoDuration(mediaAsset.duration),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: CustomColors.textSecondary,
                              fontFamily: CustomTextStyles.fontFamily,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
