import 'package:flutter/material.dart';

import '../data/sync/sync_controller.dart';

/// Signs in with Google and connects the Google Sheet that parents share.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key, required this.sync});

  final SyncController sync;

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final TextEditingController _link = TextEditingController();
  String? _linkError;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final connected = await widget.sync.connectSheet(_link.text);
    if (!mounted) return;
    setState(() {
      _linkError = connected ? null : 'Paste the full link to the sheet';
      if (connected) _link.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Sheet')),
      // ListenableBuilder rebuilds its part of the screen on notifyListeners.
      body: ListenableBuilder(
        listenable: widget.sync,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ..._account(),
            const SizedBox(height: 24),
            ..._sheet(),
            const SizedBox(height: 24),
            ..._status(),
          ],
        ),
      ),
    );
  }

  List<Widget> _account() {
    final sync = widget.sync;
    final email = sync.email;
    if (email == null) {
      return [
        const Text('Sign in with the Google account you use for the sheet.'),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: sync.signIn,
          child: const Text('Sign in with Google'),
        ),
      ];
    }
    return [
      Text('Signed in as $email'),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: sync.signOut,
          child: const Text('Sign out'),
        ),
      ),
    ];
  }

  List<Widget> _sheet() {
    final table = widget.sync.selectedChild;
    if (table == null) return const [Text('Add a table to link a sheet.')];
    if (table.spreadsheetId != null) {
      return [Text('${table.name} is linked to its Google Sheet.')];
    }
    return [
      Text(
        '${table.name} has no sheet yet. Create a blank Google Sheet, share '
        'it with the other parents as editors, and paste its link here. '
        'Everyone uses the same link.',
      ),
      TextField(
        controller: _link,
        decoration: InputDecoration(
          labelText: 'Sheet link',
          errorText: _linkError,
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          onPressed: _connect,
          child: const Text('Connect sheet'),
        ),
      ),
    ];
  }

  List<Widget> _status() {
    final sync = widget.sync;
    final localizations = MaterialLocalizations.of(context);
    final lastSynced = sync.lastSynced?.toLocal();
    return [
      Text(switch (sync.status) {
        SyncStatus.notSetUp => 'Not syncing yet',
        SyncStatus.syncing => 'Syncing…',
        SyncStatus.synced => 'Up to date',
        SyncStatus.failed => 'Not synced',
      }, style: Theme.of(context).textTheme.titleMedium),
      if (sync.message != null) Text(sync.message!),
      if (lastSynced != null)
        Text(
          'Last synced at '
          '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(lastSynced))}',
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(onPressed: sync.sync, child: const Text('Sync now')),
      ),
    ];
  }
}
