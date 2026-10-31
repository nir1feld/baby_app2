import 'package:baby_app2/data/baby_event.dart';
import 'package:baby_app2/data/event_log.dart';
import 'package:baby_app2/data/sync/event_syncer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fake_event_repository.dart';
import '../../fake_sync.dart';

BabyEvent diaper(String id) {
  return BabyEvent(
    id: id,
    type: EventType.diaper,
    timestamp: DateTime.utc(2026, 10, 31, 8),
    loggedAt: DateTime.utc(2026, 10, 31, 8),
    loggedBy: 'parent',
  );
}

void main() {
  late FakeEventRepository local;
  late FakeRemoteEventLog remote;
  late EventSyncer syncer;

  List<String> ids(List<BabyEvent> events) =>
      events.map((event) => event.id).toList();

  setUp(() {
    local = FakeEventRepository();
    remote = FakeRemoteEventLog();
    syncer = EventSyncer(local, remote);
  });

  test('uploads events the sheet is missing', () async {
    local.events.add(diaper('a'));

    final pulled = await syncer.sync();

    expect(ids(remote.events), ['a']);
    expect(pulled, 0);
  });

  test('downloads events this phone is missing', () async {
    remote.events.add(diaper('a'));

    final pulled = await syncer.sync();

    expect(ids(local.events), ['a']);
    expect(pulled, 1);
  });

  test('copies in both directions at once', () async {
    local.events.add(diaper('mine'));
    remote.events.add(diaper('theirs'));

    await syncer.sync();

    expect(ids(local.events), unorderedEquals(['mine', 'theirs']));
    expect(ids(remote.events), unorderedEquals(['mine', 'theirs']));
  });

  test('syncing twice changes nothing the second time', () async {
    local.events.add(diaper('a'));
    remote.events.add(diaper('b'));
    await syncer.sync();

    final pulled = await syncer.sync();

    expect(pulled, 0);
    expect(local.events, hasLength(2));
    expect(remote.events, hasLength(2));
  });

  test('a row copied by hand in the sheet arrives once', () async {
    remote.events.addAll([diaper('a'), diaper('a')]);

    await syncer.sync();

    expect(ids(local.events), ['a']);
  });

  test('a row deleted by hand from the sheet is put back', () async {
    local.events.add(diaper('a'));
    await syncer.sync();
    remote.events.clear();

    await syncer.sync();

    expect(ids(remote.events), ['a']);
  });

  test('a failed upload keeps what was downloaded and retries', () async {
    local.events.add(diaper('mine'));
    remote.events.add(diaper('theirs'));
    remote.failOnAppend = true;

    await expectLater(syncer.sync(), throwsException);
    expect(ids(local.events), contains('theirs'));

    remote.failOnAppend = false;
    await syncer.sync();

    expect(ids(remote.events), unorderedEquals(['mine', 'theirs']));
    expect(local.events, hasLength(2));
  });

  test('an edit from another phone applies here', () async {
    final log = EventLog(local, loggedBy: 'parent');
    await log.add(EventType.feed, amount: 100);
    await syncer.sync();

    final otherPhone = FakeEventRepository();
    final otherLog = EventLog(otherPhone, loggedBy: 'other parent');
    await EventSyncer(otherPhone, remote).sync();
    final feed = (await otherLog.currentEvents()).single;
    await otherLog.edit(feed, timestamp: feed.timestamp, amount: 150);
    await EventSyncer(otherPhone, remote).sync();

    await syncer.sync();

    expect((await log.currentEvents()).single.amount, 150);
  });

  test('a delete from another phone applies here', () async {
    final log = EventLog(local, loggedBy: 'parent');
    await log.add(EventType.diaper);
    await syncer.sync();

    final otherPhone = FakeEventRepository();
    final otherLog = EventLog(otherPhone, loggedBy: 'other parent');
    await EventSyncer(otherPhone, remote).sync();
    await otherLog.delete((await otherLog.currentEvents()).single);
    await EventSyncer(otherPhone, remote).sync();

    await syncer.sync();

    expect(await log.currentEvents(), isEmpty);
  });
}
