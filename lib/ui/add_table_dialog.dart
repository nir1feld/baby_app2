import 'package:flutter/material.dart';

import '../data/sync/sync_controller.dart';

/// Adds a table, linked to a Google Sheet if a link is given. Closes with
/// true if a table was added.
class AddTableDialog extends StatefulWidget {
  const AddTableDialog({super.key, required this.sync});

  final SyncController sync;

  @override
  State<AddTableDialog> createState() => _AddTableDialogState();
}

class _AddTableDialogState extends State<AddTableDialog> {
  final TextEditingController _link = TextEditingController();
  final TextEditingController _name = TextEditingController();
  String? _linkError;
  String? _nameError;

  @override
  void dispose() {
    _link.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final added = await widget.sync.addTable(
      name: _name.text,
      link: _link.text,
    );
    if (!mounted) return;
    if (added) {
      Navigator.of(context).pop(true);
      return;
    }
    final hasLink = _link.text.trim().isNotEmpty;
    setState(() {
      _linkError = hasLink ? 'Paste the full link to the sheet' : null;
      _nameError = hasLink ? null : 'Enter a name or a sheet link';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a table'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create a blank Google Sheet, share it with the other parents as '
            'editors, and paste its link here. To use an existing table, '
            'paste its sheet link. The tab takes the name of the sheet.',
          ),
          TextField(
            controller: _link,
            decoration: InputDecoration(
              labelText: 'Sheet link',
              errorText: _linkError,
            ),
          ),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: 'Name, if there is no sheet yet',
              errorText: _nameError,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _add, child: const Text('Add')),
      ],
    );
  }
}
