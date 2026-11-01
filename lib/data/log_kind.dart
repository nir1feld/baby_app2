import 'baby_event.dart';

/// The number a kind of log records. It's stored in [BabyEvent.amount].
class Measure {
  const Measure({required this.label, required this.unit});

  final String label;
  final String unit;

  /// How the field and sheet column are titled, such as "Amount (ml)".
  String get title => '$label ($unit)';
}

/// The facts about each kind of log that the tabs and the sheet read, so they
/// don't check which kind they have. How a kind's popup looks and behaves
/// lives in its LogPopup, in `lib/ui/popups`.
///
/// A Dart enum can hold fields, unlike a C# one: each value below is a
/// constant object built by the constructor underneath.
enum LogKind {
  feed(
    type: EventType.feed,
    title: 'Feeds',
    emptyText: 'No feeds yet',
    timeLabel: 'Time',
    measure: Measure(label: 'Amount', unit: 'ml'),
  ),
  diaper(
    type: EventType.diaper,
    title: 'Diapers',
    emptyText: 'No diapers yet',
    timeLabel: 'Time',
  ),
  sleep(
    type: EventType.sleep,
    title: 'Sleep',
    emptyText: 'No sleep yet',
    timeLabel: 'Start',
    measure: Measure(label: 'Duration', unit: 'min'),
  );

  const LogKind({
    required this.type,
    required this.title,
    required this.emptyText,
    required this.timeLabel,
    this.measure,
  });

  final EventType type;

  /// The name of its tab in the app and in the sheet.
  final String title;

  final String emptyText;

  /// What [BabyEvent.timestamp] means for this kind.
  final String timeLabel;

  /// Null if this kind records no number.
  final Measure? measure;

  /// The kind of a log. Edits and deletes are not logs, so they have none.
  static LogKind of(EventType type) {
    return values.firstWhere((kind) => kind.type == type);
  }
}
