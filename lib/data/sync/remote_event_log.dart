import '../baby_event.dart';

/// The shared copy of the event log. A backend other than Google Sheets can
/// replace this by implementing these two methods.
abstract class RemoteEventLog {
  /// Returns every readable event. May contain the same event twice, if
  /// someone copied a row by hand.
  Future<List<BabyEvent>> fetchAll();

  /// Adds [events] to the end of the log.
  Future<void> appendAll(List<BabyEvent> events);
}
