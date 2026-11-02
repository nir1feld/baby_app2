import 'package:flutter/material.dart';

import '../../data/baby_event.dart';
import '../../data/event_log.dart';
import '../../data/log_kind.dart';
import '../../data/sleep_times.dart';
import 'log_dialog_frame.dart';
import 'log_popup.dart';

/// A sleep has a start and a finish. The log stores the minutes between them,
/// so charts can use the duration directly. The finish may stay empty, for a
/// sleep that hasn't ended yet.
class SleepPopup extends LogPopup {
  const SleepPopup();

  @override
  Future<void> saveNew(EventLog log, EventType type, LogDetails details) {
    return log.addSleep(details.time, details.amount);
  }

  @override
  Widget build({
    required String title,
    required DateTime initialTime,
    double? initialAmount,
    String? warning,
  }) {
    return _SleepDialog(
      title: title,
      initialTime: initialTime,
      initialDuration: initialAmount,
      warning: warning,
    );
  }
}

class _SleepDialog extends StatefulWidget {
  const _SleepDialog({
    required this.title,
    required this.initialTime,
    this.initialDuration,
    this.warning,
  });

  final String title;
  final DateTime initialTime;
  final double? initialDuration;
  final String? warning;

  @override
  State<_SleepDialog> createState() => _SleepDialogState();
}

class _SleepDialogState extends State<_SleepDialog> {
  /// Kept up to date from the frame, so the note below follows a new start.
  late DateTime _start = widget.initialTime.toLocal();

  /// Null until a finish is chosen.
  late TimeOfDay? _finish = _initialFinish();

  /// The minutes from the start to the finish, or null with no finish.
  double? get _minutes {
    final finish = _finish;
    if (finish == null) return null;
    return sleepMinutes(_start, hour: finish.hour, minute: finish.minute);
  }

  bool get _passesMidnight {
    final minutes = _minutes;
    return minutes != null && sleepPassesMidnight(_start, minutes);
  }

  /// Such as "Spans 2 days: Oct 30 and Oct 31".
  String _spanNote() {
    final localizations = MaterialLocalizations.of(context);
    final nextDay = DateTime(_start.year, _start.month, _start.day + 1);
    final first = localizations.formatShortMonthDay(_start);
    final second = localizations.formatShortMonthDay(nextDay);
    return 'Spans 2 days: $first and $second';
  }

  TimeOfDay? _initialFinish() {
    final minutes = widget.initialDuration;
    if (minutes == null) return null;
    final finish = widget.initialTime.toLocal().add(
      Duration(minutes: minutes.round()),
    );
    return TimeOfDay.fromDateTime(finish);
  }

  Future<void> _pickFinish() async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          _finish ?? TimeOfDay.fromDateTime(widget.initialTime.toLocal()),
    );
    if (picked != null) setState(() => _finish = picked);
  }

  void _save(DateTime start) {
    _start = start;
    final LogDetails details = (time: start, amount: _minutes);
    Navigator.of(context).pop(details);
  }

  @override
  Widget build(BuildContext context) {
    final finish = _finish;
    final passesMidnight = _passesMidnight;
    return LogDialogFrame(
      title: widget.title,
      initialTime: widget.initialTime,
      timeLabel: LogKind.sleep.timeLabel,
      warning: widget.warning,
      onSave: _save,
      onTimeChanged: (start) => setState(() => _start = start),
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: _pickFinish,
              icon: const Icon(Icons.schedule),
              label: Text(
                finish == null
                    ? 'Finish: not set'
                    : 'Finish: ${finish.format(context)}'
                          '${passesMidnight ? ' (next day)' : ''}',
              ),
            ),
            if (finish != null)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Clear finish',
                onPressed: () => setState(() => _finish = null),
              ),
          ],
        ),
        if (passesMidnight)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.nights_stay_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_spanNote())),
              ],
            ),
          ),
      ],
    );
  }
}
