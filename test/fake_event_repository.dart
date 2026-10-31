import 'package:baby_app2/data/baby_event.dart';
import 'package:baby_app2/data/event_repository.dart';

/// Keeps events in a list, so tests don't need a real database.
class FakeEventRepository implements EventRepository {
  final List<BabyEvent> events = [];

  /// When true, saving fails, for testing how the app reports errors.
  bool failOnAppend = false;

  @override
  Future<void> append(BabyEvent event) async {
    if (failOnAppend) throw Exception('disk full');
    events.add(event);
  }

  @override
  Future<List<BabyEvent>> allEvents() async => List.of(events);
}
