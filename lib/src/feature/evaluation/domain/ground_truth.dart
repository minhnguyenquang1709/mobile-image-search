import 'dart:io';

/// Parsed ground-truth labels for evaluation.
///
/// CSV shape (with header):
/// ```
/// caption,file_name
/// "A woman wearing two medals holds up seven fingers",3667157255_4e66d11dc2.jpg
/// ```
/// Each row maps one caption (query) to one relevant file. The same caption may
/// appear in multiple rows, in which case all its files are collected.
class GroundTruth {
  final Map<String, List<String>> _labels;

  GroundTruth(this._labels);

  factory GroundTruth.fromCsvFile(String path) {
    final List<String> lines = File(path).readAsLinesSync();

    final Map<String, List<String>> labels = {};
    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i].trim();
      if (line.isEmpty) continue;

      final List<String> fields = _parseCsvLine(line);
      if (fields.length < 2) continue;

      final String caption = fields[0].trim();
      final String fileName = fields[1].trim();

      // skip the header row
      if (i == 0 && caption.toLowerCase() == 'caption') continue;

      labels.putIfAbsent(caption, () => []).add(fileName);
    }

    return GroundTruth(labels);
  }

  List<String> get queries => _labels.keys.toList();

  List<String> relevantFor(String query) => _labels[query] ?? const [];

  /// Parse a single CSV line into fields, honoring double-quoted fields that may
  /// contain commas and escaped quotes ("").
  static List<String> _parseCsvLine(String line) {
    final List<String> fields = [];
    final StringBuffer buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final String char = line[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          fields.add(buffer.toString());
          buffer.clear();
        } else {
          buffer.write(char);
        }
      }
    }
    fields.add(buffer.toString());

    return fields;
  }
}
