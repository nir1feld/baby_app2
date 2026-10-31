import 'dart:math';

import 'baby_event.dart';
import 'event_repository.dart';

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
    this._repository, {
    required this.loggedBy,
    this._clock = DateTime.now,
  });

  final EventRepository _repository;
  final DateTime Function() _clock;
  final Random _random = Random.secure();

  /// Who is recorded as logging events from this phone.
  final String loggedBy;

  Future<List<BabyEvent>> currentEvents() async {
    return deriveCurrentEvents(await _repository.allEvents());
  }

  /// Logs a feed, diaper or sleep. [timestamp] defaults to now.
  Future<void> add(EventType type, {DateTime? timestamp, double? amount}) {
    return _append(type, timestamp: timestamp, amount: amount);
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
    return _repository.append(
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
