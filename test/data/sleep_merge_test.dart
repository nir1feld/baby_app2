import 'package:baby_app2/data/baby_event.dart';
import 'package:baby_app2/data/event_log.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_event_repository.dart';

void main() {
  late FakeEventRepository repository;
  late EventLog log;

  DateTime at(int hour, [int minute = 0, int second = 0]) {
    return DateTime(2026, 11, 1, hour, minute, second);
  }

  Future<List<BabyEvent>> sleeps() async {
    return (await log.currentEvents())
        .where((event) => event.type == EventType.sleep)
        .toList();
  }

  void expectSleep(BabyEvent sleep, DateTime start, double minutes) {
    expect(sleep.timestamp.toLocal(), start);
    expect(sleep.amount, minutes);
  }

  setUp(() {
    repository = FakeEventRepository();
    log = EventLog(repository, loggedBy: 'parent');
  });

  test('a sleep that touches nothing is added as usual', () async {
    await log.addSleep(at(9), 60);
    await log.addSleep(at(13), 60);

    expect(await sleeps(), hasLength(2));
    expect(repository.events, hasLength(2));
  });

  test('a sleep starting as another finishes continues it', () async {
    await log.addSleep(at(9), 60);

    await log.addSleep(at(10), 30);

    expectSleep((await sleeps()).single, at(9), 90);
  });

  test('a sleep finishing as another starts continues it', () async {
    await log.addSleep(at(10), 30);

    await log.addSleep(at(9), 60);

    expectSleep((await sleeps()).single, at(9), 90);
  });

  test('overlapping sleeps merge', () async {
    await log.addSleep(at(9), 60);

    await log.addSleep(at(9, 30), 60);

    expectSleep((await sleeps()).single, at(9), 90);
  });

  test('a sleep inside another changes nothing but the log', () async {
    await log.addSleep(at(9), 120);

    await log.addSleep(at(9, 30), 15);

    expectSleep((await sleeps()).single, at(9), 120);
  });

  test('a sleep around another replaces its span', () async {
    await log.addSleep(at(9, 30), 15);

    await log.addSleep(at(9), 120);

    expectSleep((await sleeps()).single, at(9), 120);
  });

  test('a sleep bridging two others merges all three', () async {
    await log.addSleep(at(9), 60);
    await log.addSleep(at(11), 60);

    await log.addSleep(at(10), 60);

    expectSleep((await sleeps()).single, at(9), 180);
  });

  test('a gap of a minute keeps sleeps apart', () async {
    await log.addSleep(at(9), 60);

    await log.addSleep(at(10, 1), 30);

    expect(await sleeps(), hasLength(2));
  });

  test('seconds in the times do not matter', () async {
    await log.addSleep(at(9, 0, 45), 60);

    await log.addSleep(at(10, 0, 5), 30);

    expectSleep((await sleeps()).single, at(9), 90);
  });

  test('merging works past midnight', () async {
    await log.addSleep(at(23), 120);

    await log.addSleep(DateTime(2026, 11, 2, 1), 60);

    expectSleep((await sleeps()).single, at(23), 180);
  });

  test('a sleep with no finish is added, not merged', () async {
    await log.addSleep(at(9), 60);

    await log.addSleep(at(9, 30), null);

    expect(await sleeps(), hasLength(2));
  });

  test('a sleep with no finish counts as a moment at its start', () async {
    await log.addSleep(at(9, 30), null);

    await log.addSleep(at(9), 60);

    expectSleep((await sleeps()).single, at(9), 60);
  });

  test('other kinds of log are left alone', () async {
    await log.add(EventType.feed, timestamp: at(9, 30), amount: 60);

    await log.addSleep(at(9), 60);

    expect(await log.currentEvents(), hasLength(2));
  });

  test('a deleted sleep does not merge', () async {
    await log.addSleep(at(9), 60);
    await log.delete((await sleeps()).single);

    await log.addSleep(at(10), 30);

    expectSleep((await sleeps()).single, at(10), 30);
  });

  test('an edited sleep merges by its corrected times', () async {
    await log.addSleep(at(9), 60);
    await log.edit((await sleeps()).single, timestamp: at(12), amount: 60);

    await log.addSleep(at(10), 30);

    expect(await sleeps(), hasLength(2));
  });

  test('a merge is an edit and deletes, so phones can sync it', () async {
    await log.addSleep(at(9), 60);
    await log.addSleep(at(11), 60);

    await log.addSleep(at(10), 60);

    expect(repository.events.skip(2).map((event) => event.type), [
      EventType.edit,
      EventType.delete,
    ]);
  });

  test('merged sleep keeps who logged the first one', () async {
    await log.addSleep(at(9), 60);
    log.loggedBy = 'other parent';

    await log.addSleep(at(10), 30);

    expect((await sleeps()).single.loggedBy, 'parent');
  });
}
