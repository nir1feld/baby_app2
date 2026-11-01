import 'package:baby_app2/data/baby_event.dart';
import 'package:baby_app2/data/event_log.dart';
import 'package:baby_app2/data/sync/sync_controller.dart';
import 'package:baby_app2/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_event_repository.dart';
import '../fake_sync.dart';

const link = 'https://docs.google.com/spreadsheets/d/sheet-1/edit';

void main() {
  late FakeEventRepository local;
  late FakeRemoteEventLog remote;
  late FakeSyncAccount account;
  late SyncController sync;
  late EventLog eventLog;

  Future<void> openHome(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(eventLog: eventLog, sync: sync),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSyncScreen(WidgetTester tester) async {
    await openHome(tester);
    await tester.tap(find.byTooltip('Google Sheet'));
    await tester.pumpAndSettle();
  }

  Future<void> connect(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.text('Connect sheet'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    local = FakeEventRepository();
    remote = FakeRemoteEventLog();
    account = FakeSyncAccount(remote);
    sync = SyncController(
      local: local,
      settings: FakeSettingsStore(),
      account: account,
    );
    eventLog = EventLog(local, loggedBy: 'parent');
  });

  testWidgets('the app works without Google set up', (tester) async {
    await openHome(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Log feed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
    expect(local.events, hasLength(1));
  });

  testWidgets('signing in and connecting a sheet starts syncing', (
    tester,
  ) async {
    await eventLog.add(EventType.diaper);
    await openSyncScreen(tester);

    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();
    expect(find.text('Signed in as parent@example.com'), findsOneWidget);

    await connect(tester, link);

    expect(find.text('Up to date'), findsOneWidget);
    expect(remote.events, hasLength(1));
  });

  testWidgets('a bad link shows an error', (tester) async {
    await openSyncScreen(tester);

    await connect(tester, 'not a link');

    expect(find.text('Paste the full link to the sheet'), findsOneWidget);
  });

  testWidgets('a failed sign-in shows the reason', (tester) async {
    account.failSignIn = true;
    await openSyncScreen(tester);

    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();

    expect(find.text('sign-in failed'), findsOneWidget);
    expect(find.text('Not synced'), findsOneWidget);
  });

  testWidgets('logging an event uploads it in the background', (tester) async {
    await sync.signIn();
    await sync.connectSheet(link);
    await openHome(tester);

    await tester.tap(find.text('Diapers'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log diaper'));
    await tester.pumpAndSettle();

    expect(remote.events, hasLength(1));
    expect(find.byIcon(Icons.cloud_done), findsOneWidget);
  });

  testWidgets('offline, logging still works and the icon says so', (
    tester,
  ) async {
    await sync.signIn();
    await sync.connectSheet(link);
    await openHome(tester);
    remote.offline = true;

    await tester.tap(find.text('Diapers'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log diaper'));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsOneWidget);
    expect(find.byIcon(Icons.sync_problem), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('events from another parent appear on the home screen', (
    tester,
  ) async {
    await sync.signIn();
    await sync.connectSheet(link);
    await openHome(tester);
    expect(find.byType(ListTile), findsNothing);

    remote.events.add(
      BabyEvent(
        id: 'theirs',
        type: EventType.feed,
        timestamp: DateTime.now(),
        loggedAt: DateTime.now(),
        loggedBy: 'other parent',
        amount: 100,
      ),
    );
    await sync.sync();
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsOneWidget);
  });
}
