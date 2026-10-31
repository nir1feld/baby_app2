import 'package:flutter/material.dart';

/// Lets the user set an event's time and, for feeds, its amount in ml.
/// Closes with the chosen values, or null if cancelled. The return type is a
/// record: a small unnamed bundle of two values.
class EventDialog extends StatefulWidget {
  const EventDialog({
    super.key,
    required this.title,
    required this.initialTime,
    required this.showAmount,
    this.initialAmount,
  });

  final String title;
  final DateTime initialTime;
  final bool showAmount;
  final double? initialAmount;

  @override
  State<EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<EventDialog> {
  late DateTime _time = widget.initialTime.toLocal();
  late final TextEditingController _amount = TextEditingController(
    text: widget.initialAmount?.toString() ?? '',
  );
  String? _amountError;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

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

  void _save() {
    final text = _amount.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(text);
    if (text.isNotEmpty && (amount == null || amount < 0)) {
      setState(() => _amountError = 'Enter a number, or leave empty');
      return;
    }
    Navigator.of(context).pop((time: _time, amount: amount));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.schedule),
            label: Text(
              MaterialLocalizations.of(
                context,
              ).formatTimeOfDay(TimeOfDay.fromDateTime(_time)),
            ),
          ),
          if (widget.showAmount)
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount (ml)',
                errorText: _amountError,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
