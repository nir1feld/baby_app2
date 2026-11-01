import 'package:flutter/material.dart';

/// What every popup shares: the title, an optional warning, the time button,
/// and Cancel and Save. A popup puts its own controls in [children], the way
/// a master page holds content in ASP.NET. The frame knows nothing about them.
class LogDialogFrame extends StatefulWidget {
  const LogDialogFrame({
    super.key,
    required this.title,
    required this.initialTime,
    required this.onSave,
    this.timeLabel,
    this.warning,
    this.children = const [],
  });

  final String title;
  final DateTime initialTime;

  /// Shown before the time, when the time needs explaining.
  final String? timeLabel;

  /// Shown at the top of the dialog when set.
  final String? warning;

  final List<Widget> children;

  /// Called with the chosen time when Save is tapped. The popup checks its
  /// own controls, then closes the dialog with its result.
  final ValueChanged<DateTime> onSave;

  @override
  State<LogDialogFrame> createState() => _LogDialogFrameState();
}

class _LogDialogFrameState extends State<LogDialogFrame> {
  late DateTime _time = widget.initialTime.toLocal();

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_time),
    );
    if (picked != null) {
      setState(() {
        _time = DateTime(
          _time.year,
          _time.month,
          _time.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(_time));
    final timeLabel = widget.timeLabel;
    return AlertDialog(
      title: Text(widget.title),
      // Lets the content scroll when the keyboard leaves it too little room.
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.warning != null) DialogWarning(widget.warning!),
          TextButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.schedule),
            label: Text(timeLabel == null ? time : '$timeLabel: $time'),
          ),
          ...widget.children,
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => widget.onSave(_time),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// A warning line for the top of a dialog.
class DialogWarning extends StatelessWidget {
  const DialogWarning(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Row(
      children: [
        Icon(Icons.warning_amber, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: color)),
        ),
      ],
    );
  }
}
