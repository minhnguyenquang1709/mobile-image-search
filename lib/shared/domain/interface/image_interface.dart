import 'package:mobile_image_search/core/constants/common_constant.dart';

class IMediaMetadata {
  final String name;
  final DateTime createDateTime;
  final DateTime modifiedDateTime;
  final EMediaType mediaType;
  int duration;

  IMediaMetadata({
    required this.name,
    required this.createDateTime,
    required this.modifiedDateTime,
    required this.mediaType,
    this.duration = 0,
  });
}
