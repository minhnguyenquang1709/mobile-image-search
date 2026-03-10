class IImageMetadata {
  final String name;
  final DateTime createDateTime;
  final DateTime modifiedDateTime;

  IImageMetadata({
    required this.name,
    required this.createDateTime,
    required this.modifiedDateTime,
  });
}
