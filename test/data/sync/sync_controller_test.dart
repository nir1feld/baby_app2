import 'package:baby_app2/data/baby_event.dart';
import 'package:baby_app2/data/sync/sync_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fake_event_repository.dart';
import '../../fake_sync.dart';

const link = 'https://docs.google.com/spreadsheets/d/sheet-1/edit';
const otherLink = 'https://docs.google.com/spreadsheets/d/sheet-2/edit';

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
  late FakeSyncAccount account;
  late FakeSettingsStore settings;
  late FakeChildStore store;
  late SyncController sync;

  Future<void> addSheet(String sheetLink) async {
    await sync.addTable(link: sheetLink);
    await sync.sync();
  }

  setUp(() async {
    local = FakeEventRepository();
    remote = FakeRemoteEventLog();
    account = FakeSyncAccount(remote);
    settings = FakeSettingsStore();
    store = FakeChildStore(local);
    sync = SyncController(
      store: store,
      settings: settings,
      account: account,
      clock: () => DateTime.utc(2026, 10, 31, 12),
    );
    await sync.load();
  });

  group('several children', () {
    late FakeRemoteEventLog secondSheet;

    setUp(() async {
      secondSheet = FakeRemoteEventLog(title: 'Second child');
      account.otherSheets['sheet-2'] = secondSheet;
      await sync.signIn();
      await sync.connectSheet(link);
    });

    test('the first sheet goes to the child already on this phone', () {
      expect(sync.children, hasLength(1));
      expect(sync.spreadsheetId, 'sheet-1');
    });

    test('a child takes the name of their sheet', () {
      expect(sync.selectedChild!.name, 'Sheet title');
    });

    test('a renamed sheet renames the child at the next sync', () async {
      remote.title = 'New name';

      await sync.sync();

      expect(sync.selectedChild!.name, 'New name');
    });

    test('another link adds a child and selects them', () async {
      await addSheet(otherLink);

      expect(sync.children, hasLength(2));
      expect(sync.spreadsheetId, 'sheet-2');
      expect(sync.selectedChild!.name, 'Second child');
    });

    test('adding a child keeps the logs of both sheets apart', () async {
      local.events.add(diaper('first-child'));
      secondSheet.events.add(diaper('second-child'));

      await addSheet(otherLink);

      final saved = await sync.selectedEvents!.allEvents();
      expect(saved.map((event) => event.id), ['second-child']);
      expect(remote.events.map((event) => event.id), ['first-child']);
      expect(secondSheet.events.map((event) => event.id), ['second-child']);
    });

    test('a link already connected selects that child', () async {
      await addSheet(otherLink);

      await sync.connectSheet(link);

      expect(sync.children, hasLength(2));
      expect(sync.spreadsheetId, 'sheet-1');
    });

    test('a sync covers children that are not on screen', () async {
      await addSheet(otherLink);
      local.events.add(diaper('first-child'));

      await sync.sync();

      expect(remote.events.map((event) => event.id), ['first-child']);
    });

    test('a failing sheet does not stop the others, and is named', () async {
      await addSheet(otherLink);
      remote.offline = true;
      store.events('sheet-2').events.add(diaper('second-child'));

      await sync.sync();

      expect(secondSheet.events, hasLength(1));
      expect(sync.status, SyncStatus.failed);
      expect(sync.message, 'Sheet title: offline');
    });

    test('remembers the selected child on the next start', () async {
      await addSheet(otherLink);

      final restarted = SyncController(
        store: store,
        settings: settings,
        account: account,
      );
      await restarted.load();

      expect(restarted.spreadsheetId, 'sheet-2');
    });

    test('removing a child selects another and keeps their sheet', () async {
      await addSheet(otherLink);
      secondSheet.events.add(diaper('second-child'));
      await sync.sync();

      await sync.removeTable(sync.selectedChild!.id);

      expect(sync.children, hasLength(1));
      expect(sync.spreadsheetId, 'sheet-1');
      expect(secondSheet.events, hasLength(1));
    });

    test('a removed sheet brings its logs back when added again', () async {
      await addSheet(otherLink);
      secondSheet.events.add(diaper('second-child'));
      await sync.sync();
      await sync.removeTable(sync.selectedChild!.id);

      await addSheet(otherLink);

      final saved = await sync.selectedEvents!.allEvents();
      expect(saved.map((event) => event.id), ['second-child']);
    });

    test('removing the last table leaves none', () async {
      await sync.removeTable(sync.selectedChild!.id);

      expect(sync.children, isEmpty);
      expect(sync.selectedChild, isNull);
      expect(sync.selectedEvents, isNull);
      expect(sync.status, SyncStatus.notSetUp);
    });

    test('removing a failing table clears the failure', () async {
      await addSheet(otherLink);
      secondSheet.offline = true;
      await sync.sync();
      expect(sync.status, SyncStatus.failed);

      await sync.removeTable(sync.selectedChild!.id);

      expect(sync.status, SyncStatus.synced);
      expect(sync.message, isNull);
    });

    test('a table can be added with a name and no sheet', () async {
      final added = await sync.addTable(name: ' Second ');

      expect(added, isTrue);
      expect(sync.selectedChild!.name, 'Second');
      expect(sync.spreadsheetId, isNull);
    });

    test('a table needs a name or a valid link', () async {
      expect(await sync.addTable(), isFalse);
      expect(await sync.addTable(name: 'Second', link: 'bad'), isFalse);

      expect(sync.children, hasLength(1));
    });

    test('a table without a sheet can be linked later', () async {
      await sync.addTable(name: 'Second');

      await sync.connectSheet(otherLink);

      expect(sync.children, hasLength(2));
      expect(sync.spreadsheetId, 'sheet-2');
      expect(sync.selectedChild!.name, 'Second child');
    });
  });

  test('a new phone has no tables and syncs nothing', () async {
    store.list.clear();
    await sync.load();
    await sync.signIn();

    expect(sync.children, isEmpty);
    expect(sync.selectedChild, isNull);
    expect(sync.status, SyncStatus.notSetUp);
    expect(await sync.connectSheet(link), isFalse);
  });

  test('does nothing until signed in with a sheet connected', () async {
    local.events.add(diaper('a'));

    await sync.sync();
    expect(sync.status, SyncStatus.notSetUp);

    await sync.signIn();
    expect(sync.status, SyncStatus.notSetUp);
    expect(remote.events, isEmpty);

    await sync.connectSheet(link);
    expect(sync.status, SyncStatus.synced);
    expect(remote.events, hasLength(1));
    expect(account.lastSpreadsheetId, 'sheet-1');
    expect(sync.lastSynced, DateTime.utc(2026, 10, 31, 12));
  });

  test('a sheet can be connected before signing in', () async {
    await sync.connectSheet(link);
    expect(sync.status, SyncStatus.notSetUp);

    await sync.signIn();

    expect(sync.status, SyncStatus.synced);
  });

  test('rejects a bad link and keeps the current sheet', () async {
    await sync.connectSheet(link);

    final connected = await sync.connectSheet('not a link');

    expect(connected, isFalse);
    expect(sync.spreadsheetId, 'sheet-1');
  });

  test('remembers the sheet and sign-in on the next start', () async {
    await sync.connectSheet(link);

    final account2 = FakeSyncAccount(remote)..restoredEmail = 'a@example.com';
    final restarted = SyncController(
      store: store,
      settings: settings,
      account: account2,
    );
    await restarted.load();
    await restarted.start();

    expect(restarted.spreadsheetId, 'sheet-1');
    expect(restarted.email, 'a@example.com');
    expect(restarted.status, SyncStatus.synced);
  });

  test('being offline is a status, not an error thrown at the app', () async {
    await sync.signIn();
    await sync.connectSheet(link);
    remote.offline = true;

    await sync.sync();

    expect(sync.status, SyncStatus.failed);
    expect(sync.message, 'offline');
  });

  test('the next sync recovers and uploads what was waiting', () async {
    await sync.signIn();
    await sync.connectSheet(link);
    remote.offline = true;
    local.events.add(diaper('offline'));
    await sync.sync();

    remote.offline = false;
    await sync.sync();

    expect(sync.status, SyncStatus.synced);
    expect(sync.message, isNull);
    expect(remote.events, hasLength(1));
  });

  test('an event logged during a sync is uploaded right after it', () async {
    await sync.signIn();
    await sync.connectSheet(link);
    remote.duringFetch = () async {
      local.events.add(diaper('during'));
      await sync.sync();
    };

    await sync.sync();

    expect(remote.events.map((event) => event.id), ['during']);
    expect(sync.status, SyncStatus.synced);
  });

  test('a sheet connected during a sync is used right after it', () async {
    await sync.signIn();
    await sync.connectSheet(link);
    remote.duringFetch = () async {
      await addSheet(otherLink);
    };

    await sync.sync();

    expect(account.lastSpreadsheetId, 'sheet-2');
  });

  test('a sheet connected during a failing sync is still tried', () async {
    await sync.signIn();
    await sync.connectSheet(link);
    local.events.add(diaper('a'));
    remote.failOnAppend = true;
    remote.duringFetch = () async {
      await addSheet(otherLink);
    };

    await sync.sync();

    expect(account.lastSpreadsheetId, 'sheet-2');
  });

  test('counts events that arrive, so screens can reload', () async {
    await sync.signIn();
    await sync.connectSheet(link);
    expect(sync.pulledCount, 0);

    remote.events.add(diaper('a'));
    await sync.sync();

    expect(sync.pulledCount, 1);
  });

  test('a failed sign-in shows why', () async {
    account.failSignIn = true;

    await sync.signIn();

    expect(sync.status, SyncStatus.failed);
    expect(sync.message, 'sign-in failed');
    expect(sync.email, isNull);
  });

  test('signing out stops syncing', () async {
    await sync.signIn();
    await sync.connectSheet(link);

    await sync.signOut();
    local.events.add(diaper('a'));
    await sync.sync();

    expect(sync.status, SyncStatus.notSetUp);
    expect(remote.events, isEmpty);
  });
}
