import 'package:flutter/material.dart';

import '../../data/amount_text.dart';
import '../../data/feed_amounts.dart';

/// Buttons for the usual feed amounts. Tapping one calls [onPicked]. The edit
/// button next to them switches to changing the list, which is the only time
/// it can change. The default amount has a star.
class FeedAmountPicker extends StatefulWidget {
  const FeedAmountPicker({
    super.key,
    required this.amounts,
    required this.currentAmount,
    required this.onPicked,
  });

  final FeedAmounts amounts;

  /// The amount in the dialog's field, so its button can show as chosen.
  final double? currentAmount;

  final ValueChanged<double> onPicked;

  @override
  State<FeedAmountPicker> createState() => _FeedAmountPickerState();
}

class _FeedAmountPickerState extends State<FeedAmountPicker> {
  final TextEditingController _newAmount = TextEditingController();
  bool _editing = false;

  /// The amount highlighted while editing.
  double? _highlighted;
  String? _newAmountError;

  @override
  void dispose() {
    _newAmount.dispose();
    super.dispose();
  }

  void _toggleEditing() {
    setState(() {
      _editing = !_editing;
      _highlighted = null;
      _newAmountError = null;
      _newAmount.clear();
    });
  }

  void _tap(double value) {
    if (_editing) {
      setState(() => _highlighted = _highlighted == value ? null : value);
    } else {
      widget.onPicked(value);
    }
  }

  Future<void> _setDefault() async {
    await widget.amounts.setDefault(_highlighted!);
    if (mounted) setState(() {});
  }

  Future<void> _remove() async {
    await widget.amounts.remove(_highlighted!);
    if (mounted) setState(() => _highlighted = null);
  }

  Future<void> _add() async {
    final amount = parseAmount(_newAmount.text);
    final added = amount != null && await widget.amounts.add(amount);
    if (!mounted) return;
    setState(() {
      _newAmountError = added ? null : 'Enter a new amount above 0';
      if (added) _newAmount.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buttons()),
            IconButton(
              icon: Icon(_editing ? Icons.check : Icons.edit),
              tooltip: _editing ? 'Done editing amounts' : 'Edit amounts',
              onPressed: _toggleEditing,
            ),
          ],
        ),
        if (_editing) ..._editControls(),
      ],
    );
  }

  Widget _buttons() {
    final amounts = widget.amounts;
    final chosen = _editing ? _highlighted : widget.currentAmount;
    if (amounts.values.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No saved amounts'),
      );
    }
    // Wrap flows its children onto new lines when a row is full.
    return Wrap(
      spacing: 8,
      children: [
        for (final value in amounts.values)
          ChoiceChip(
            label: Text(formatAmount(value)),
            avatar: value == amounts.defaultAmount
                ? const Icon(Icons.star, size: 18)
                : null,
            showCheckmark: false,
            selected: value == chosen,
            onSelected: (_) => _tap(value),
          ),
      ],
    );
  }

  List<Widget> _editControls() {
    final highlighted = _highlighted;
    return [
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            // A null onPressed greys the button out.
            onPressed:
                highlighted == null ||
                    highlighted == widget.amounts.defaultAmount
                ? null
                : _setDefault,
            child: const Text('Set as default'),
          ),
          OutlinedButton(
            onPressed: highlighted == null ? null : _remove,
            child: const Text('Remove'),
          ),
        ],
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _newAmount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'New amount (ml)',
                errorText: _newAmountError,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(onPressed: _add, child: const Text('Add')),
          ),
        ],
      ),
    ];
  }
}
