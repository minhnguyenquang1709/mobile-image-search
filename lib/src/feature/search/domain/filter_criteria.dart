import 'package:flutter/foundation.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

enum SearchMode { semantic, filename }

/// filter = date constraints + file types
@immutable
class FilterCriteria {
  /// lower bound on the capture date
  final DateTime? startDate;

  /// upper bound on the capture date
  final DateTime? endDate;

  final int? year;

  /// 1 = Jan… 12 = Dec, empty = any month
  final Set<int> months;

  /// 1 = Mon… 7 = Sun, empty = any day
  final Set<int> daysOfWeek;

  /// file formats to match, empty = any format
  final Set<EMediaFormat> formats;

  const FilterCriteria({
    this.startDate,
    this.endDate,
    this.year,
    this.months = const {},
    this.daysOfWeek = const {},
    this.formats = const {},
  });

  /// Whether any constraint is set (drives whether to show the search view and
  /// whether the date range can be pushed down to the device query)
  bool get isActive =>
      startDate != null ||
      endDate != null ||
      year != null ||
      months.isNotEmpty ||
      daysOfWeek.isNotEmpty ||
      formats.isNotEmpty;

  /// Whether [asset] satisfies every set constraint (unset constraints skipped)
  bool matches(MediaAsset asset) {
    final DateTime date = asset.createDateTime;

    if (startDate != null && date.isBefore(startDate!)) return false;
    if (endDate != null && date.isAfter(endDate!)) return false;
    if (year != null && date.year != year) return false;
    if (months.isNotEmpty && !months.contains(date.month)) return false;
    if (daysOfWeek.isNotEmpty && !daysOfWeek.contains(date.weekday)) {
      return false;
    }
    if (formats.isNotEmpty && !formats.contains(asset.format)) return false;

    return true;
  }

  FilterCriteria copyWith({
    DateTime? startDate,
    DateTime? endDate,
    int? year,
    Set<int>? months,
    Set<int>? daysOfWeek,
    Set<EMediaFormat>? formats,
  }) {
    return FilterCriteria(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      year: year ?? this.year,
      months: months ?? this.months,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      formats: formats ?? this.formats,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FilterCriteria &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.year == year &&
        setEquals(other.months, months) &&
        setEquals(other.daysOfWeek, daysOfWeek) &&
        setEquals(other.formats, formats);
  }

  @override
  int get hashCode => Object.hash(
    startDate,
    endDate,
    year,
    Object.hashAllUnordered(months),
    Object.hashAllUnordered(daysOfWeek),
    Object.hashAllUnordered(formats),
  );
}
