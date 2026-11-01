/// What an event records. [edit] and [delete] change an earlier event.
enum EventType { feed, diaper, sleep, edit, delete }

/// One row of the append-only event log. Events are never changed once saved.
class BabyEvent {
  const BabyEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.loggedAt,
    required this.loggedBy,
    this.amount,
    this.referencesId,
  });

  /// Rebuilds an event from a stored row.
  factory BabyEvent.fromMap(Map<String, Object?> map) {
    return BabyEvent(
      id: map['id'] as String,
      type: EventType.values.byName(map['type'] as String),
      timestamp: _dateFromMillis(map['timestamp'] as int),
      loggedAt: _dateFromMillis(map['logged_at'] as int),
      loggedBy: map['logged_by'] as String,
      amount: map['amount'] as double?,
      referencesId: map['references_id'] as String?,
    );
  }

  final String id;
  final EventType type;

  /// When the thing happened. For an edit, the corrected time.
  final DateTime timestamp;

  /// When this row was written. Decides which of two edits is newer.
  final DateTime loggedAt;

  final String loggedBy;

  /// The number this kind of log records: ml for a feed, minutes for a sleep.
  /// For an edit, the corrected number.
  final double? amount;

  /// The event that an edit or delete applies to.
  final String? referencesId;

  /// True for edit and delete events, which are not shown on their own.
  bool get isChange => type == EventType.edit || type == EventType.delete;

  /// A copy of this event with the corrected values from [edit].
  BabyEvent withEdit(BabyEvent edit) {
    return BabyEvent(
      id: id,
      type: type,
      timestamp: edit.timestamp,
      loggedAt: loggedAt,
      loggedBy: loggedBy,
      amount: edit.amount,
    );
  }

  /// Times are stored as UTC milliseconds so all phones agree on them.
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'type': type.name,
      'timestamp': timestamp.toUtc().millisecondsSinceEpoch,
      'logged_at': loggedAt.toUtc().millisecondsSinceEpoch,
      'logged_by': loggedBy,
      'amount': amount,
      'references_id': referencesId,
    };
  }

  static DateTime _dateFromMillis(int millis) {
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }
}
