/// A model representing an album, which can contain multiple media assets.
class Album {
  final String id;
  final String title;
  String? description;

  Album({required this.id, required this.title, this.description});
}
