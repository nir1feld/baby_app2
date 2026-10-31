import 'package:flutter/material.dart';

import '../data/baby_event.dart';
import '../data/event_log.dart';
import 'day_picker_dialog.dart';
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

  /// The earlier day being viewed, or null for today. Null rather than a date
  /// so that "today" moves on by itself at midnight.
  DateTime? _pickedDay;

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _changeAndReload(() async {});
    // The app may have sat in the background past midnight.
    _lifecycleListener = AppLifecycleListener(
      onResume: () => _changeAndReload(() async {}),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = widget.eventLog.now().toLocal();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _day => _pickedDay ?? _today;

  void _showDay(DateTime day) {
    setState(() => _pickedDay = day == _today ? null : day);
  }

  /// Moves by whole days. DateTime rolls day 0 back into the previous month.
  void _moveDay(int days) {
    final day = _day;
    _showDay(DateTime(day.year, day.month, day.day + days));
  }

  Future<void> _pickDay() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => DayPickerDialog(
        selectedDay: _day,
        today: _today,
        loggedDays: daysWithEvents(_events ?? const []),
      ),
    );
    if (picked != null && mounted) _showDay(picked);
  }

  /// Warns before anything is changed on an earlier day. Null on today.
  String? get _pastDayWarning {
    if (_pickedDay == null) return null;
    final date = MaterialLocalizations.of(context).formatFullDate(_day);
    return 'This is not today. You are changing $date.';
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
        warning: _pastDayWarning,
      ),
    );
  }

  /// Today, a diaper or sleep logs with one tap. Feeds need an amount, and an
  /// earlier day needs the warning and a time, so those open the dialog.
  Future<void> _addEvent(EventType type) async {
    final isFeed = type == EventType.feed;
    final isToday = _pickedDay == null;
    if (!isFeed && isToday) {
      await _changeAndReload(() => widget.eventLog.add(type));
      return;
    }

    final now = widget.eventLog.now().toLocal();
    final day = _day;
    final details = await _askDetails(
      title: 'Log ${type.name}',
      initialTime: isToday
          ? now
          : DateTime(day.year, day.month, day.day, now.hour, now.minute),
      showAmount: isFeed,
    );
    if (details == null) return;
    await _changeAndReload(
      () => widget.eventLog.add(
        type,
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
    final warning = _pastDayWarning;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete this ${_label(event)}?'),
        content: warning == null ? null : DialogWarning(warning),
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
            : Column(
                children: [
                  _dayBar(),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _eventTab(events, EventType.feed, 'No feeds yet'),
                        _eventTab(events, EventType.diaper, 'No diapers yet'),
                        _eventTab(events, EventType.sleep, 'No sleep yet'),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Shared by all tabs: arrows to step through days, and a calendar button.
  Widget _dayBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous day',
          onPressed: () => _moveDay(-1),
        ),
        TextButton.icon(
          onPressed: _pickDay,
          icon: const Icon(Icons.calendar_today),
          label: Text(_dayLabel()),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next day',
          // A null onPressed greys the button out: there is no tomorrow yet.
          onPressed: _pickedDay == null ? null : () => _moveDay(1),
        ),
      ],
    );
  }

  String _dayLabel() {
    final today = _today;
    final day = _day;
    if (day == today) return 'Today';
    if (day == DateTime(today.year, today.month, today.day - 1)) {
      return 'Yesterday';
    }
    return MaterialLocalizations.of(context).formatMediumDate(day);
  }

  /// One tab: the latest event of [type] on any day, a button to log one, and
  /// the list for the day being viewed.
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
          onPressed: () => _addEvent(type),
          child: Text('Log ${type.name}'),
        ),
        const Divider(),
        Expanded(
          child: _eventList(
            eventsOnDay(
              events,
              _day,
            ).where((event) => event.type == type).toList(),
          ),
        ),
      ],
    );
  }

  Widget _eventList(List<BabyEvent> events) {
    if (events.isEmpty) {
      return const Center(child: Text('Nothing logged on this day'));
    }
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
