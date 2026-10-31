import 'package:baby_app2/data/baby_event.dart';
import 'package:baby_app2/data/event_log.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_event_repository.dart';

void main() {
  late FakeEventRepository repository;
  late EventLog log;
  late DateTime now;

  setUp(() {
    repository = FakeEventRepository();
    now = DateTime.utc(2026, 10, 31, 12);
    log = EventLog(
      repository,
      loggedBy: 'parent',
      clock: () {
        // Move on a minute per event, so edits have a clear order.
        now = now.add(const Duration(minutes: 1));
        return now;
      },
    );
  });

  test('add stores an event with a unique ID and who logged it', () async {
    await log.add(EventType.feed, amount: 120);
    await log.add(EventType.feed, amount: 90);

    final saved = repository.events;
    expect(saved[0].id, isNot(saved[1].id));
    expect(saved[0].loggedBy, 'parent');
    expect(saved[0].amount, 120);
  });

  test(
    'current events are sorted newest first by when they happened',
    () async {
      final earlier = DateTime.utc(2026, 10, 31, 8);
      final later = DateTime.utc(2026, 10, 31, 9);
      await log.add(EventType.diaper, timestamp: later);
      await log.add(EventType.sleep, timestamp: earlier);

      final types = (await log.currentEvents()).map((event) => event.type);
      expect(types, [EventType.diaper, EventType.sleep]);
    },
  );

  test('editing appends an event and leaves the original untouched', () async {
    await log.add(EventType.feed, amount: 120);
    final original = (await log.currentEvents()).single;

    await log.edit(original, timestamp: original.timestamp, amount: 150);

    expect(repository.events, hasLength(2));
    expect(repository.events.first.amount, 120);
    final current = (await log.currentEvents()).single;
    expect(current.id, original.id);
    expect(current.type, EventType.feed);
    expect(current.amount, 150);
  });

  test('the latest edit wins, whatever order the rows arrive in', () async {
    await log.add(EventType.feed, amount: 120);
    final original = (await log.currentEvents()).single;
    await log.edit(original, timestamp: original.timestamp, amount: 130);
    await log.edit(original, timestamp: original.timestamp, amount: 140);

    final shuffled = repository.events.reversed.toList();

    expect(deriveCurrentEvents(shuffled).single.amount, 140);
  });

  test('an edit can clear the amount', () async {
    await log.add(EventType.feed, amount: 120);
    final original = (await log.currentEvents()).single;

    await log.edit(original, timestamp: original.timestamp);

    expect((await log.currentEvents()).single.amount, isNull);
  });

  test('deleting hides the event but keeps it in the log', () async {
    await log.add(EventType.diaper);
    final original = (await log.currentEvents()).single;

    await log.delete(original);

    expect(await log.currentEvents(), isEmpty);
    expect(repository.events, hasLength(2));
    expect(repository.events.last.referencesId, original.id);
  });

  test('an edit cannot bring back a deleted event', () async {
    await log.add(EventType.feed, amount: 120);
    final original = (await log.currentEvents()).single;

    await log.delete(original);
    await log.edit(original, timestamp: original.timestamp, amount: 150);

    expect(await log.currentEvents(), isEmpty);
  });

  test('latestOfType skips other types and deleted events', () async {
    final feedTime = DateTime.utc(2026, 10, 31, 8);
    await log.add(EventType.feed, timestamp: feedTime, amount: 100);
    await log.add(EventType.feed, timestamp: feedTime.add(_hour), amount: 110);
    await log.add(EventType.diaper, timestamp: feedTime.add(_hour * 2));

    final newestFeed = latestOfType(await log.currentEvents(), EventType.feed)!;
    expect(newestFeed.amount, 110);

    await log.delete(newestFeed);

    final remaining = await log.currentEvents();
    expect(latestOfType(remaining, EventType.feed)?.amount, 100);
  });

  test('latestOfType is null when there are none of that type', () {
    expect(latestOfType([], EventType.feed), isNull);
  });
}

const _hour = Duration(hours: 1);
