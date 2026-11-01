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
  late SyncController sync;

  setUp(() {
    local = FakeEventRepository();
    remote = FakeRemoteEventLog();
    account = FakeSyncAccount(remote);
    settings = FakeSettingsStore();
    sync = SyncController(
      local: local,
      settings: settings,
      account: account,
      clock: () => DateTime.utc(2026, 10, 31, 12),
    );
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
      local: local,
      settings: settings,
      account: account2,
    );
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
      await sync.connectSheet(otherLink);
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
      await sync.connectSheet(otherLink);
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
