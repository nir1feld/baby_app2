import 'dart:math';

import 'baby_event.dart';
import 'event_repository.dart';
import 'log_kind.dart';
import 'sleep_merge.dart';

/// Works out what the log currently says, newest first: edits are applied,
/// and deleted events are left out.
List<BabyEvent> deriveCurrentEvents(List<BabyEvent> log) {
  final deletedIds = {
    for (final event in log)
      if (event.type == EventType.delete) event.referencesId,
  };
  final current = {
    for (final event in log)
      if (!event.isChange && !deletedIds.contains(event.id)) event.id: event,
  };

  // Apply edits oldest first, so the latest edit wins.
  final edits = log.where((event) => event.type == EventType.edit).toList()
    ..sort(_byLoggedAt);
  for (final edit in edits) {
    final original = current[edit.referencesId];
    if (original != null) {
      current[original.id] = original.withEdit(edit);
    }
  }

  return current.values.toList()..sort(_newestFirst);
}

/// The newest event of [type] in [currentEvents], or null if there are none.
BabyEvent? latestOfType(List<BabyEvent> currentEvents, EventType type) {
  for (final event in currentEvents) {
    if (event.type == type) return event;
  }
  return null;
}

/// When [event] ends. A kind whose amount is minutes, such as a sleep, ends
/// that many minutes after it starts. Anything else lasts a single moment.
/// [event] must be a log, not an edit or delete, which have no kind.
DateTime eventEnd(BabyEvent event) {
  final amount = event.amount;
  final isMinutes = LogKind.of(event.type).measure?.isMinutes ?? false;
  if (amount == null || !isMinutes) return event.timestamp;
  return event.timestamp.add(Duration(minutes: amount.round()));
}

/// The events in [currentEvents] that happened on the local day [day], or
/// started earlier and were still going on it. A sleep from 22:00 to 06:00
/// shows on both days. One that ends exactly at midnight shows only on the
/// day it started.
List<BabyEvent> eventsOnDay(List<BabyEvent> currentEvents, DateTime day) {
  final dayStart = DateTime(day.year, day.month, day.day);
  // DateTime rolls day 32 over into the next month.
  final nextDay = DateTime(day.year, day.month, day.day + 1);
  return currentEvents.where((event) {
    final start = event.timestamp;
    if (start.isBefore(dayStart)) return eventEnd(event).isAfter(dayStart);
    return start.isBefore(nextDay);
  }).toList();
}

/// The local days [event] happens on, in order: one day, or more for a sleep
/// that carries on past midnight. Ending exactly at midnight adds no day.
List<DateTime> daysOf(BabyEvent event) {
  final end = eventEnd(event);
  final days = <DateTime>[];
  var day = _localDay(event.timestamp);
  // do-while runs once before checking, so the start day always counts.
  do {
    days.add(day);
    day = DateTime(day.year, day.month, day.day + 1);
  } while (day.isBefore(end));
  return days;
}

/// The local days that have at least one event in [currentEvents], counting
/// every day a sleep carries on into.
Set<DateTime> daysWithEvents(List<BabyEvent> currentEvents) {
  // `...` spreads a list into the set, like AddRange in C#.
  return {for (final event in currentEvents) ...daysOf(event)};
}

DateTime _localDay(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Comparing IDs on a tie gives every phone the same order.
int _byLoggedAt(BabyEvent a, BabyEvent b) {
  final byTime = a.loggedAt.compareTo(b.loggedAt);
  return byTime != 0 ? byTime : a.id.compareTo(b.id);
}

int _newestFirst(BabyEvent a, BabyEvent b) {
  final byTime = b.timestamp.compareTo(a.timestamp);
  return byTime != 0 ? byTime : b.id.compareTo(a.id);
}

/// The actions the UI can take on the log.
class EventLog {
  EventLog(
    this.repository, {
    required this.loggedBy,
    this._clock = DateTime.now,
  });

  /// Who is recorded as logging events from this phone. Not final, because it
  /// changes when someone signs in.
  String loggedBy;

  /// The selected table's events, or null if there are no tables. Not final,
  /// because switching tabs changes it.
  EventRepository? repository;

  final DateTime Function() _clock;
  final Random _random = Random.secure();

  DateTime now() => _clock();

  Future<List<BabyEvent>> currentEvents() async {
    final events = await repository?.allEvents();
    return deriveCurrentEvents(events ?? const []);
  }

  /// Logs a feed, diaper or sleep. [timestamp] defaults to now.
  Future<void> add(EventType type, {DateTime? timestamp, double? amount}) {
    return _append(type, timestamp: timestamp, amount: amount);
  }

  /// Logs a sleep, or folds it into the sleeps it overlaps or continues. A
  /// merge is an edit and deletes, like any other change to the log. A sleep
  /// with no [minutes] hasn't ended, so it has nothing to merge yet.
  Future<void> addSleep(DateTime timestamp, double? minutes) async {
    final merge = minutes == null
        ? null
        : planSleepMerge(await currentEvents(), timestamp, minutes);
    if (merge == null) {
      await add(EventType.sleep, timestamp: timestamp, amount: minutes);
      return;
    }
    await edit(merge.keep, timestamp: merge.start, amount: merge.minutes);
    for (final sleep in merge.remove) {
      await delete(sleep);
    }
  }

  /// Corrects the time and amount of [original].
  Future<void> edit(
    BabyEvent original, {
    required DateTime timestamp,
    double? amount,
  }) {
    return _append(
      EventType.edit,
      timestamp: timestamp,
      amount: amount,
      referencesId: original.id,
    );
  }

  Future<void> delete(BabyEvent original) {
    return _append(EventType.delete, referencesId: original.id);
  }

  Future<void> _append(
    EventType type, {
    DateTime? timestamp,
    double? amount,
    String? referencesId,
  }) {
    final now = _clock();
    // Logging needs a table, and the UI only offers it when there is one.
    return repository!.append(
      BabyEvent(
        id: _newId(),
        type: type,
        timestamp: timestamp ?? now,
        loggedAt: now,
        loggedBy: loggedBy,
        amount: amount,
        referencesId: referencesId,
      ),
    );
  }

  /// 16 random bytes as hex: unique across phones without a central counter.
  String _newId() {
    return List.generate(
      16,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
