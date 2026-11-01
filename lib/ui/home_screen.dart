import 'dart:async';

import 'package:flutter/material.dart';

import '../data/amount_text.dart';
import '../data/baby_event.dart';
import '../data/child.dart';
import '../data/event_log.dart';
import '../data/log_kind.dart';
import '../data/sync/sync_controller.dart';
import 'add_table_dialog.dart';
import 'day_picker_dialog.dart';
import 'popups/log_dialog_frame.dart';
import 'popups/log_popup.dart';
import 'sync_screen.dart';

/// Logs feeds, diapers and sleep, each in its own tab.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.eventLog,
    required this.sync,
    required this.popups,
  });

  final EventLog eventLog;
  final SyncController sync;
  final Map<LogKind, LogPopup> popups;

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

  /// The sync's pulled count when the list was last loaded.
  late int _loadedPulledCount = widget.sync.pulledCount;

  /// The table whose list was last loaded.
  late String? _loadedChildId = widget.sync.selectedChild?.id;

  @override
  void initState() {
    super.initState();
    widget.sync.addListener(_reloadIfDataChanged);
    _changeAndReload(() async {});
    // The app may have sat in the background past midnight.
    _lifecycleListener = AppLifecycleListener(
      onResume: () => _changeAndReload(() async {}),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    widget.sync.removeListener(_reloadIfDataChanged);
    super.dispose();
  }

  void _reloadIfDataChanged() {
    final pulledCount = widget.sync.pulledCount;
    final childId = widget.sync.selectedChild?.id;
    if (pulledCount == _loadedPulledCount && childId == _loadedChildId) return;
    _loadedPulledCount = pulledCount;
    _loadedChildId = childId;
    _reload();
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

  /// Runs [change], reloads the list, then syncs in the background. unawaited
  /// means "don't wait for this", so a slow network never holds up the screen.
  Future<void> _changeAndReload(Future<void> Function() change) async {
    await _reload(change);
    unawaited(widget.sync.sync());
  }

  /// Failures are shown to the user, so nobody assumes an event was saved
  /// when it wasn't.
  Future<void> _reload([Future<void> Function()? change]) async {
    try {
      await change?.call();
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

  void _openSyncScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SyncScreen(sync: widget.sync)),
    );
  }

  /// Sync runs after the dialog closes, so a slow network can't hold it open.
  /// Linking a sheet needs a sign-in, so that screen opens if there is none.
  Future<void> _addTable() async {
    final sync = widget.sync;
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => AddTableDialog(sync: sync),
    );
    if (added != true) return;
    unawaited(sync.sync());
    if (mounted && sync.email == null && sync.spreadsheetId != null) {
      _openSyncScreen();
    }
  }

  Future<void> _removeTable(Child table) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${table.name} from this phone?'),
        content: const Text(
          'The Google Sheet is not changed, and you can add it again with its '
          'link. Logs that have not synced yet will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.sync.removeTable(table.id);
  }

  /// One tab per table, and a button to add another. The key rebuilds the tab
  /// controller when the tabs or the selection change, because a controller
  /// can't change its length.
  Widget _tableBar() {
    final sync = widget.sync;
    final tables = sync.children;
    final selected = sync.selectedChild;
    final ids = tables.map((table) => table.id).join(',');
    return Row(
      children: [
        Expanded(
          child: DefaultTabController(
            key: ValueKey('$ids|${selected?.id}'),
            length: tables.length,
            initialIndex: tables.indexWhere(
              (table) => table.id == selected?.id,
            ),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              onTap: (index) => sync.selectChild(tables[index].id),
              tabs: [
                for (final table in tables)
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(table.name),
                        if (table.id == selected?.id)
                          IconButton(
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 28,
                            ),
                            icon: const Icon(Icons.close),
                            tooltip: 'Remove table',
                            onPressed: () => _removeTable(table),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Add table',
          onPressed: _addTable,
        ),
      ],
    );
  }

  /// What a new phone shows, before there is anywhere to log.
  Widget _noTables() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No tables yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a table and link it to a Google Sheet to start logging.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _addTable,
              child: const Text('Create a table'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _syncIcon() {
    return switch (widget.sync.status) {
      SyncStatus.notSetUp => Icons.cloud_off,
      SyncStatus.syncing => Icons.cloud_sync,
      SyncStatus.synced => Icons.cloud_done,
      SyncStatus.failed => Icons.sync_problem,
    };
  }

  /// The ! says "not null here": every kind has a popup.
  LogPopup _popupOf(LogKind kind) => widget.popups[kind]!;

  Future<LogDetails?> _askDetails({
    required String title,
    required DateTime initialTime,
    required LogKind kind,
    double? initialAmount,
  }) {
    return showDialog<LogDetails>(
      context: context,
      builder: (_) => _popupOf(kind).build(
        title: title,
        initialTime: initialTime,
        initialAmount: initialAmount,
        warning: _pastDayWarning,
      ),
    );
  }

  /// A popup can log with one tap today. An earlier day always needs the
  /// warning and a time, so it opens the popup.
  Future<void> _addEvent(LogKind kind) async {
    final popup = _popupOf(kind);
    final isToday = _pickedDay == null;
    if (popup.logsWithOneTap && isToday) {
      await _changeAndReload(() => widget.eventLog.add(kind.type));
      return;
    }

    final now = widget.eventLog.now().toLocal();
    final day = _day;
    final details = await _askDetails(
      title: 'Log ${kind.name}',
      initialTime: isToday
          ? now
          : DateTime(day.year, day.month, day.day, now.hour, now.minute),
      kind: kind,
      initialAmount: popup.newAmount,
    );
    if (details == null) return;
    await _changeAndReload(
      () => widget.eventLog.add(
        kind.type,
        timestamp: details.time,
        amount: details.amount,
      ),
    );
  }

  Future<void> _edit(BabyEvent event) async {
    final details = await _askDetails(
      title: 'Edit ${_label(event)}',
      initialTime: event.timestamp,
      kind: LogKind.of(event.type),
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
    final unit = LogKind.of(event.type).measure?.unit;
    if (amount == null || unit == null) return time;
    return '$time, ${formatAmount(amount)} $unit';
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds the screen when a table is added, removed or selected, and
    // when the sync status changes.
    return ListenableBuilder(
      listenable: widget.sync,
      builder: (context, _) => _scaffold(),
    );
  }

  Widget _scaffold() {
    final events = _events;
    final hasTables = widget.sync.children.isNotEmpty;
    // DefaultTabController keeps the TabBar and TabBarView on the same tab.
    return DefaultTabController(
      length: LogKind.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BabyLog'),
          actions: [
            IconButton(
              icon: Icon(_syncIcon()),
              tooltip: 'Google Sheet',
              onPressed: _openSyncScreen,
            ),
          ],
          // PreferredSize tells the AppBar how tall these two rows are.
          bottom: hasTables
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2 * kTextTabBarHeight),
                  child: Column(
                    children: [
                      _tableBar(),
                      TabBar(
                        tabs: [
                          for (final kind in LogKind.values)
                            Tab(text: kind.title),
                        ],
                      ),
                    ],
                  ),
                )
              : null,
        ),
        body: !hasTables
            ? _noTables()
            : events == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _dayBar(),
                  Expanded(
                    child: TabBarView(
                      children: [
                        for (final kind in LogKind.values)
                          _eventTab(events, kind),
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

  /// One tab: the latest log of [kind] on any day, a button to log one, and
  /// the list for the day being viewed.
  Widget _eventTab(List<BabyEvent> events, LogKind kind) {
    final latest = latestOfType(events, kind.type);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            latest == null
                ? kind.emptyText
                : 'Last ${kind.name}: ${_describe(latest)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        FilledButton(
          onPressed: () => _addEvent(kind),
          child: Text('Log ${kind.name}'),
        ),
        const Divider(),
        Expanded(
          child: _eventList(
            eventsOnDay(
              events,
              _day,
            ).where((event) => event.type == kind.type).toList(),
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
