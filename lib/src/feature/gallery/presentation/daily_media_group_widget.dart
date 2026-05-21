import 'package:flutter/widgets.dart';
import 'package:mobile_image_search/src/common_widgets/thumbnail_widget.dart';
import 'package:mobile_image_search/src/constants/config_constant.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

class DailyMediaGroupWidget extends StatelessWidget {
  final DailyMediaGroup _mediaGroup;
  const DailyMediaGroupWidget({super.key, required DailyMediaGroup mediaGroup})
    : _mediaGroup = mediaGroup;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // date header
        Padding(
          padding: EdgeInsets.all(4),
          child: Text(_mediaGroup.datetime.toString().split(' ')[0]),
        ),

        // shrink wrap grid
        GridView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(), // disable inner grid scrolling
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: UIConfig.thumbnailsPerRow,
            crossAxisSpacing: UIConfig.gridCrossAxisSpacing,
            mainAxisSpacing: UIConfig.gridMainAxisSpacing,
          ),
          itemCount: _mediaGroup.mediaAssets.length,
          itemBuilder: (context, index) {
            final mediaAsset = _mediaGroup.mediaAssets[index];
            return ThumbnailWidget(
              assetId: mediaAsset.assetId,
              key: ValueKey(mediaAsset.assetId),
            );
          },
        ),
      ],
    );
  }
}
