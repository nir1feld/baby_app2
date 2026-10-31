import 'baby_event.dart';

/// Where events are stored. The app only uses this interface, so a hosted
/// backend can replace the local database by implementing these two methods.
///
/// There is deliberately no update or delete: the log is append-only.
abstract class EventRepository {
  /// Adds [event] to the end of the log.
  Future<void> append(BabyEvent event);

  /// Returns every event ever saved, including edits and deletes.
  Future<List<BabyEvent>> allEvents();
}
