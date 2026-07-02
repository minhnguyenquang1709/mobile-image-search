import 'package:mobile_image_search/src/core/utils/exceptions.dart';
import 'package:mobile_image_search/src/feature/search/domain/query_validator.dart';

class AlbumFormValidator {
  final QueryValidator _queryValidator;

  AlbumFormValidator({required QueryValidator queryValidator})
    : _queryValidator = queryValidator;

  static const int maxNameLength = 50;

  // blacklist
  static final RegExp _invalidNameChars = RegExp(r'[\\/:*?"<>|]');

  void validate(String name, String? description) {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      throw InvalidAlbumNameException('Album name cannot be empty.');
    }
    if (trimmedName.length > maxNameLength) {
      throw InvalidAlbumNameException(
        'Album name must be at most $maxNameLength characters.',
      );
    }
    if (_invalidNameChars.hasMatch(trimmedName)) {
      throw InvalidAlbumNameException(
        'Album name cannot contain \\ / : * ? " < > |',
      );
    }

    final desc = description?.trim() ?? '';
    if (desc.isNotEmpty) {
      _queryValidator.validate(desc);
    }
  }
}
