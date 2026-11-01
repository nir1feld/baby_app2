import 'package:flutter/material.dart';

import '../../data/amount_text.dart';
import '../../data/feed_amounts.dart';
import '../../data/log_kind.dart';
import 'feed_amount_picker.dart';
import 'log_dialog_frame.dart';
import 'log_popup.dart';

/// A feed has a time and an amount, with buttons for the usual amounts.
class FeedPopup extends LogPopup {
  const FeedPopup(this._amounts);

  final FeedAmounts _amounts;

  @override
  double? get newAmount => _amounts.defaultAmount;

  @override
  Widget build({
    required String title,
    required DateTime initialTime,
    double? initialAmount,
    String? warning,
  }) {
    return _FeedDialog(
      amounts: _amounts,
      title: title,
      initialTime: initialTime,
      initialAmount: initialAmount,
      warning: warning,
    );
  }
}

class _FeedDialog extends StatefulWidget {
  const _FeedDialog({
    required this.amounts,
    required this.title,
    required this.initialTime,
    this.initialAmount,
    this.warning,
  });

  final FeedAmounts amounts;
  final String title;
  final DateTime initialTime;
  final double? initialAmount;
  final String? warning;

  @override
  State<_FeedDialog> createState() => _FeedDialogState();
}

class _FeedDialogState extends State<_FeedDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: _initialText(),
  );
  String? _amountError;

  String _initialText() {
    final amount = widget.initialAmount;
    return amount == null ? '' : formatAmount(amount);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save(DateTime time) {
    final amount = parseAmount(_amount.text);
    if (_amount.text.trim().isNotEmpty && (amount == null || amount < 0)) {
      setState(() => _amountError = 'Enter a number, or leave empty');
      return;
    }
    final LogDetails details = (time: time, amount: amount);
    Navigator.of(context).pop(details);
  }

  @override
  Widget build(BuildContext context) {
    return LogDialogFrame(
      title: widget.title,
      initialTime: widget.initialTime,
      warning: widget.warning,
      onSave: _save,
      children: [
        // Rebuilds when the field changes, so the matching button lights up.
        // A TextEditingController notifies listeners like a ChangeNotifier.
        ListenableBuilder(
          listenable: _amount,
          builder: (context, _) => FeedAmountPicker(
            amounts: widget.amounts,
            currentAmount: parseAmount(_amount.text),
            onPicked: (amount) => _amount.text = formatAmount(amount),
          ),
        ),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: LogKind.feed.measure!.title,
            errorText: _amountError,
          ),
        ),
      ],
    );
  }
}
