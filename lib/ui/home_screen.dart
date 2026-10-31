import 'package:flutter/material.dart';

import '../data/baby_event.dart';
import '../data/event_log.dart';
import 'event_dialog.dart';

/// Logs feeds, diapers and sleep, each in its own tab.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.eventLog});

  final EventLog eventLog;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Null until the first load finishes.
  List<BabyEvent>? _events;

  @override
  void initState() {
    super.initState();
    _changeAndReload(() async {});
  }

  /// Runs [change], then reloads the list. Failures are shown to the user, so
  /// nobody assumes an event was saved when it wasn't.
  Future<void> _changeAndReload(Future<void> Function() change) async {
    try {
      await change();
      final events = await widget.eventLog.currentEvents();
      if (!mounted) return;
      setState(() => _events = events);
    } catch (error) {
      if (!mounted) return;
      setState(() => _events ??= const []);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Something went wrong: $error')));
    }
  }

  Future<({DateTime time, double? amount})?> _askDetails({
    required String title,
    required DateTime initialTime,
    required bool showAmount,
    double? initialAmount,
  }) {
    return showDialog(
      context: context,
      builder: (_) => EventDialog(
        title: title,
        initialTime: initialTime,
        showAmount: showAmount,
        initialAmount: initialAmount,
      ),
    );
  }

  Future<void> _addFeed() async {
    final details = await _askDetails(
      title: 'Log feed',
      initialTime: DateTime.now(),
      showAmount: true,
    );
    if (details == null) return;
    await _changeAndReload(
      () => widget.eventLog.add(
        EventType.feed,
        timestamp: details.time,
        amount: details.amount,
      ),
    );
  }

  Future<void> _edit(BabyEvent event) async {
    final details = await _askDetails(
      title: 'Edit ${_label(event)}',
      initialTime: event.timestamp,
      showAmount: event.type == EventType.feed,
      initialAmount: event.amount,
    );
    if (details == null) return;
    await _changeAndReload(
      () => widget.eventLog.edit(
        event,
        timestamp: details.time,
        amount: details.amount,
      ),
    );
  }

  Future<void> _delete(BabyEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete this ${_label(event)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _changeAndReload(() => widget.eventLog.delete(event));
  }

  String _label(BabyEvent event) => event.type.name;

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatShortMonthDay(local);
    final clock = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date, $clock';
  }

  String _describe(BabyEvent event) {
    final time = _formatTime(event.timestamp);
    final amount = event.amount;
    return amount == null ? time : '$time, $amount ml';
  }

  @override
  Widget build(BuildContext context) {
    final events = _events;
    // DefaultTabController keeps the TabBar and TabBarView on the same tab.
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Baby Tracker'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Feeds'),
              Tab(text: 'Diapers'),
              Tab(text: 'Sleep'),
            ],
          ),
        ),
        body: events == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _eventTab(events, EventType.feed, 'No feeds yet'),
                  _eventTab(events, EventType.diaper, 'No diapers yet'),
                  _eventTab(events, EventType.sleep, 'No sleep yet'),
                ],
              ),
      ),
    );
  }

  /// One tab: the latest event of [type], a button to log one, and the list.
  Widget _eventTab(List<BabyEvent> events, EventType type, String emptyText) {
    final latest = latestOfType(events, type);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            latest == null
                ? emptyText
                : 'Last ${type.name}: ${_describe(latest)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        FilledButton(
          onPressed: type == EventType.feed
              ? _addFeed
              : () => _changeAndReload(() => widget.eventLog.add(type)),
          child: Text('Log ${type.name}'),
        ),
        const Divider(),
        Expanded(
          child: _eventList(
            events.where((event) => event.type == type).toList(),
          ),
        ),
      ],
    );
  }

  Widget _eventList(List<BabyEvent> events) {
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return ListTile(
          title: Text(_label(event)),
          subtitle: Text(_describe(event)),
          onTap: () => _edit(event),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () => _delete(event),
          ),
        );
      },
    );
  }
}
