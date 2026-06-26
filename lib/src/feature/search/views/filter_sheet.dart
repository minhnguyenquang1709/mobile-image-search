import 'package:flutter/material.dart';
import 'package:mobile_image_search/src/feature/search/domain/filter_criteria.dart';
import 'package:mobile_image_search/src/shared/domain/model/media_asset.dart';

/// Bottom sheet that edits a [FilterCriteria]. Seeded from [initial] and returns
/// the built criteria via [Navigator.pop] (or an empty one when cleared).
class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key, required this.initial});

  final FilterCriteria initial;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  // File formats the user can choose from (unknown is excluded).
  static const List<EMediaFormat> _selectableFormats = [
    EMediaFormat.jpg,
    EMediaFormat.png,
    EMediaFormat.webp,
    EMediaFormat.gif,
    EMediaFormat.mp4,
    EMediaFormat.mkv,
    EMediaFormat.webm,
  ];

  static const List<String> _monthLabels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  DateTime? _startDate;
  DateTime? _endDate;
  int? _year;
  final Set<int> _months = {};
  final Set<int> _daysOfWeek = {};
  final Set<EMediaFormat> _formats = {};

  @override
  void initState() {
    super.initState();
    _startDate = widget.initial.startDate;
    _endDate = widget.initial.endDate;
    _year = widget.initial.year;
    _months.addAll(widget.initial.months);
    _daysOfWeek.addAll(widget.initial.daysOfWeek);
    _formats.addAll(widget.initial.formats);
  }

  String _formatLabel(EMediaFormat format) {
    switch (format) {
      case EMediaFormat.jpg:
        return 'jpg/jpeg';
      case EMediaFormat.png:
        return 'png';
      case EMediaFormat.webp:
        return 'webp';
      case EMediaFormat.gif:
        return 'gif';
      case EMediaFormat.mp4:
        return 'mp4';
      case EMediaFormat.mkv:
        return 'mkv';
      case EMediaFormat.webm:
        return 'webm';
      case EMediaFormat.unknown:
        return 'unknown';
    }
  }

  String _dateRangeLabel() {
    if (_startDate == null && _endDate == null) return 'Any date';
    final String start = _startDate == null
        ? '…'
        : _startDate!.toString().split(' ')[0];
    final String end = _endDate == null
        ? '…'
        : _endDate!.toString().split(' ')[0];
    return '$start  →  $end';
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
      initialDateRange: (_startDate != null && _endDate != null)
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
    });
  }

  /// Build the criteria from the current selections, normalizing the end date to
  /// the end of its day so the range is inclusive.
  FilterCriteria _buildCriteria() {
    DateTime? normalizedEnd;
    if (_endDate != null) {
      normalizedEnd = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        23,
        59,
        59,
      );
    }

    return FilterCriteria(
      startDate: _startDate,
      endDate: normalizedEnd,
      year: _year,
      months: Set<int>.from(_months),
      daysOfWeek: Set<int>.from(_daysOfWeek),
      formats: Set<EMediaFormat>.from(_formats),
    );
  }

  List<int> _yearOptions() {
    final int currentYear = DateTime.now().year;
    return [for (int y = currentYear; y >= currentYear - 20; y--) y];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Date range
            const Text('Date range'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(Icons.date_range),
              label: Text(_dateRangeLabel()),
            ),
            const SizedBox(height: 16),

            // Year
            const Text('Year'),
            const SizedBox(height: 8),
            DropdownButton<int?>(
              value: _year,
              hint: const Text('Any year'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Any')),
                for (final y in _yearOptions())
                  DropdownMenuItem<int?>(value: y, child: Text('$y')),
              ],
              onChanged: (value) => setState(() => _year = value),
            ),
            const SizedBox(height: 16),

            // Months
            const Text('Months'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (int m = 1; m <= 12; m++)
                  FilterChip(
                    label: Text(_monthLabels[m - 1]),
                    selected: _months.contains(m),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _months.add(m);
                        } else {
                          _months.remove(m);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Days of week
            const Text('Days of week'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (int d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(_weekdayLabels[d - 1]),
                    selected: _daysOfWeek.contains(d),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _daysOfWeek.add(d);
                        } else {
                          _daysOfWeek.remove(d);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // File types
            const Text('File types'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final format in _selectableFormats)
                  FilterChip(
                    label: Text(_formatLabel(format)),
                    selected: _formats.contains(format),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _formats.add(format);
                        } else {
                          _formats.remove(format);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(const FilterCriteria()),
                  child: const Text('Clear'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_buildCriteria()),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
