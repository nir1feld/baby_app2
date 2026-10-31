import 'package:flutter/material.dart';

/// A month calendar that shades the days in [loggedDays] and closes with the
/// tapped day. Flutter's own date picker can't highlight individual days.
class DayPickerDialog extends StatefulWidget {
  const DayPickerDialog({
    super.key,
    required this.selectedDay,
    required this.today,
    required this.loggedDays,
  });

  final DateTime selectedDay;
  final DateTime today;
  final Set<DateTime> loggedDays;

  @override
  State<DayPickerDialog> createState() => _DayPickerDialogState();
}

class _DayPickerDialogState extends State<DayPickerDialog> {
  late DateTime _month = DateTime(
    widget.selectedDay.year,
    widget.selectedDay.month,
  );

  bool get _isCurrentMonth =>
      _month.year == widget.today.year && _month.month == widget.today.month;

  /// Month 0 and month 13 roll over into the neighbouring years.
  void _moveMonth(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.all(16),
      contentPadding: const EdgeInsets.all(12),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous month',
            onPressed: () => _moveMonth(-1),
          ),
          Text(
            localizations.formatMonthYear(_month),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
            onPressed: _isCurrentMonth ? null : () => _moveMonth(1),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          children: [_weekdayRow(localizations), ..._weekRows(localizations)],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _weekdayRow(MaterialLocalizations localizations) {
    final first = localizations.firstDayOfWeekIndex;
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Text(localizations.narrowWeekdays[(first + i) % 7]),
            ),
          ),
      ],
    );
  }

  List<Widget> _weekRows(MaterialLocalizations localizations) {
    final blanks = DateUtils.firstDayOffset(
      _month.year,
      _month.month,
      localizations,
    );
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);

    // The cells of the month in order, with null for the blanks at each end.
    final cells = <int?>[
      for (var i = 0; i < blanks; i++) null,
      for (var day = 1; day <= days; day++) day,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return [
      for (var start = 0; start < cells.length; start += 7)
        Row(
          children: [
            for (final day in cells.sublist(start, start + 7))
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: day == null ? null : _dayCell(day),
                ),
              ),
          ],
        ),
    ];
  }

  Widget _dayCell(int dayOfMonth) {
    final day = DateTime(_month.year, _month.month, dayOfMonth);
    final colors = Theme.of(context).colorScheme;
    final isFuture = day.isAfter(widget.today);
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: isFuture ? null : () => Navigator.of(context).pop(day),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.loggedDays.contains(day)
              ? colors.primaryContainer
              : null,
          border: day == widget.selectedDay
              ? Border.all(color: colors.primary, width: 2)
              : null,
        ),
        child: Center(
          child: Text(
            '$dayOfMonth',
            style: TextStyle(
              color: isFuture ? Theme.of(context).disabledColor : null,
              fontWeight: day == widget.today ? FontWeight.bold : null,
            ),
          ),
        ),
      ),
    );
  }
}
