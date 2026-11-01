import '../baby_event.dart';

/// The shared copy of the event log. A backend other than Google Sheets can
/// replace this by implementing these methods.
abstract class RemoteEventLog {
  /// The log's title, shown as the child's name.
  Future<String> fetchTitle();

  /// Returns every readable event. May contain the same event twice, if
  /// someone copied a row by hand.
  Future<List<BabyEvent>> fetchAll();

  /// Adds [events] to the end of the log.
  Future<void> appendAll(List<BabyEvent> events);

  /// Replaces the readable copy of the log with [currentEvents], which are
  /// the logs as they stand now, newest first, without edits and deletes.
  Future<void> writeSummary(List<BabyEvent> currentEvents);
}
