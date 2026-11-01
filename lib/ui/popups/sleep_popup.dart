import 'package:flutter/material.dart';

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
  /// Null until a finish is chosen.
  late TimeOfDay? _finish = _initialFinish();

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
    final finish = _finish;
    final LogDetails details = (
      time: start,
      amount: finish == null
          ? null
          : sleepMinutes(start, hour: finish.hour, minute: finish.minute),
    );
    Navigator.of(context).pop(details);
  }

  @override
  Widget build(BuildContext context) {
    final finish = _finish;
    return LogDialogFrame(
      title: widget.title,
      initialTime: widget.initialTime,
      timeLabel: LogKind.sleep.timeLabel,
      warning: widget.warning,
      onSave: _save,
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: _pickFinish,
              icon: const Icon(Icons.schedule),
              label: Text(
                finish == null
                    ? 'Finish: not set'
                    : 'Finish: ${finish.format(context)}',
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
      ],
    );
  }
}
