import 'package:baby_app2/data/baby_event.dart';
import 'package:baby_app2/data/event_log.dart';
import 'package:baby_app2/data/sync/sync_controller.dart';
import 'package:baby_app2/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_event_repository.dart';
import '../fake_sync.dart';

const notToday = 'This is not today';
const secondLink = 'https://docs.google.com/spreadsheets/d/sheet-2/edit';

void main() {
  late FakeEventRepository repository;
  late FakeChildStore store;
  late EventLog eventLog;
  late SyncController sync;
  late DateTime now;

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(eventLog: eventLog, sync: sync),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> logFeed(WidgetTester tester, String amount) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Log feed'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), amount);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String name) async {
    await tester.tap(find.widgetWithText(Tab, name));
    await tester.pumpAndSettle();
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(FilledButton, label));
    await tester.pumpAndSettle();
  }

  Future<void> tapTooltip(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    repository = FakeEventRepository();
    now = DateTime(2026, 10, 31, 12);
    eventLog = EventLog(repository, loggedBy: 'parent', clock: () => now);
    store = FakeChildStore(repository);
    sync = SyncController(
      store: store,
      settings: FakeSettingsStore(),
      account: FakeSyncAccount(FakeRemoteEventLog()),
    );
    await sync.load();
    sync.addListener(() => eventLog.repository = sync.selectedEvents);
  });

  Future<void> addTableWithDialog(
    WidgetTester tester, {
    String name = '',
    String link = '',
  }) async {
    await tapTooltip(tester, 'Add table');
    await tester.enterText(find.byType(TextField).first, link);
    await tester.enterText(find.byType(TextField).last, name);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
  }

  testWidgets('a new phone offers to create a table', (tester) async {
    store.list.clear();
    await sync.load();
    await openScreen(tester);

    expect(find.text('No tables yet'), findsOneWidget);
    expect(find.text('Feeds'), findsNothing);

    await tester.tap(find.text('Create a table'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Second');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('No tables yet'), findsNothing);
    expect(find.text('Feeds'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('each table has a tab with its own logs', (tester) async {
    await openScreen(tester);
    await logFeed(tester, '120');

    await addTableWithDialog(tester, name: 'Second');
    expect(find.text('Baby'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);

    await logFeed(tester, '60');
    expect(find.text('Oct 31, 12:00 PM, 60.0 ml'), findsOneWidget);

    await tester.tap(find.text('Baby'));
    await tester.pumpAndSettle();

    expect(find.text('Oct 31, 12:00 PM, 120.0 ml'), findsOneWidget);
    expect(find.text('Oct 31, 12:00 PM, 60.0 ml'), findsNothing);
  });

  testWidgets('a table added with a link asks to sign in', (tester) async {
    await openScreen(tester);

    await addTableWithDialog(tester, link: secondLink);

    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(sync.spreadsheetId, 'sheet-2');
  });

  testWidgets('the add dialog explains what is wrong', (tester) async {
    await openScreen(tester);

    await addTableWithDialog(tester);
    expect(find.text('Enter a name or a sheet link'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'not a link');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Paste the full link to the sheet'), findsOneWidget);
    expect(sync.children, hasLength(1));
  });

  testWidgets('closing a tab asks first, then removes the table', (
    tester,
  ) async {
    await openScreen(tester);
    await addTableWithDialog(tester, name: 'Second');

    await tapTooltip(tester, 'Remove table');
    expect(find.text('Remove Second from this phone?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(sync.children, hasLength(2));

    await tapTooltip(tester, 'Remove table');
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(sync.children, hasLength(1));
    expect(find.text('Second'), findsNothing);
  });

  testWidgets('closing the last tab offers to create a table', (tester) async {
    await openScreen(tester);

    await tapTooltip(tester, 'Remove table');
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(find.text('No tables yet'), findsOneWidget);
  });

  testWidgets('starts empty', (tester) async {
    await openScreen(tester);

    expect(find.text('No feeds yet'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('logging a feed lists it and updates the last feed', (
    tester,
  ) async {
    await openScreen(tester);

    await logFeed(tester, '120');

    expect(repository.events.single.amount, 120);
    expect(find.textContaining('Last feed:'), findsOneWidget);
    expect(find.textContaining('120.0 ml'), findsNWidgets(2));
  });

  testWidgets('a bad amount is refused and nothing is saved', (tester) async {
    await openScreen(tester);

    await logFeed(tester, 'lots');

    expect(find.text('Enter a number, or leave empty'), findsOneWidget);
    expect(repository.events, isEmpty);
  });

  testWidgets('diaper and sleep log with one tap', (tester) async {
    await openScreen(tester);

    await openTab(tester, 'Diapers');
    await tapButton(tester, 'Log diaper');
    await openTab(tester, 'Sleep');
    await tapButton(tester, 'Log sleep');

    expect(repository.events.map((event) => event.type), [
      EventType.diaper,
      EventType.sleep,
    ]);
    expect(find.text('sleep'), findsOneWidget);
  });

  testWidgets('each tab shows only its own type of event', (tester) async {
    await openScreen(tester);
    await logFeed(tester, '120');
    await openTab(tester, 'Diapers');

    expect(find.text('No diapers yet'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);

    await tapButton(tester, 'Log diaper');

    expect(find.textContaining('Last diaper:'), findsOneWidget);
    expect(find.text('diaper'), findsOneWidget);
    expect(find.text('feed'), findsNothing);

    await openTab(tester, 'Feeds');

    expect(find.text('feed'), findsOneWidget);
    expect(find.text('diaper'), findsNothing);

    await openTab(tester, 'Sleep');

    expect(find.text('No sleep yet'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('tapping a row edits it by appending an edit event', (
    tester,
  ) async {
    await openScreen(tester);
    await logFeed(tester, '120');

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '150');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.events, hasLength(2));
    expect(repository.events.last.type, EventType.edit);
    expect(find.textContaining('150.0 ml'), findsNWidgets(2));
    expect(find.textContaining('120.0 ml'), findsNothing);
  });

  testWidgets('deleting asks first, then removes the row', (tester) async {
    await openScreen(tester);
    await logFeed(tester, '120');

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNothing);
    expect(find.text('No feeds yet'), findsOneWidget);
  });

  testWidgets('shows only today until an earlier day is chosen', (
    tester,
  ) async {
    final yesterday = DateTime(2026, 10, 30, 9);
    await eventLog.add(EventType.feed, timestamp: yesterday, amount: 100);
    await eventLog.add(
      EventType.feed,
      timestamp: DateTime(2026, 10, 31, 9),
      amount: 200,
    );
    await openScreen(tester);

    expect(find.text('Today'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.textContaining('200.0 ml'), findsNWidgets(2));
    expect(find.textContaining('100.0 ml'), findsNothing);

    await tapTooltip(tester, 'Previous day');

    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.textContaining('100.0 ml'), findsOneWidget);
    // The line at the top still shows the newest feed of all.
    expect(find.textContaining('Last feed:'), findsOneWidget);
    expect(find.textContaining('200.0 ml'), findsOneWidget);

    await tapTooltip(tester, 'Next day');

    expect(find.text('Today'), findsOneWidget);
    expect(find.textContaining('100.0 ml'), findsNothing);
  });

  testWidgets('the day stays the same when switching tabs', (tester) async {
    await eventLog.add(EventType.diaper, timestamp: DateTime(2026, 10, 30, 9));
    await openScreen(tester);

    await tapTooltip(tester, 'Previous day');
    await openTab(tester, 'Diapers');

    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('a feed can be added to an earlier day, with a warning', (
    tester,
  ) async {
    await openScreen(tester);
    await tapTooltip(tester, 'Previous day');

    await tapButton(tester, 'Log feed');
    expect(find.textContaining(notToday), findsOneWidget);
    expect(find.textContaining('October 30, 2026'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '90');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = repository.events.single;
    expect(saved.amount, 90);
    expect(saved.timestamp.toLocal().day, 30);
    expect(saved.loggedAt, now);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('on an earlier day, a diaper asks first instead of one tap', (
    tester,
  ) async {
    await openScreen(tester);
    await tapTooltip(tester, 'Previous day');
    await openTab(tester, 'Diapers');

    await tapButton(tester, 'Log diaper');

    expect(repository.events, isEmpty);
    expect(find.textContaining(notToday), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.events.single.type, EventType.diaper);
    expect(repository.events.single.timestamp.toLocal().day, 30);
  });

  testWidgets('cancelling on an earlier day saves nothing', (tester) async {
    await openScreen(tester);
    await tapTooltip(tester, 'Previous day');

    await tapButton(tester, 'Log feed');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.events, isEmpty);
  });

  testWidgets('there is no warning when changing today', (tester) async {
    await openScreen(tester);

    await tapButton(tester, 'Log feed');
    expect(find.textContaining(notToday), findsNothing);
    await tester.enterText(find.byType(TextField), '120');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(find.textContaining(notToday), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.textContaining(notToday), findsNothing);
  });

  testWidgets('deleting on an earlier day warns', (tester) async {
    await eventLog.add(EventType.feed, timestamp: DateTime(2026, 10, 30, 9));
    await openScreen(tester);
    await tapTooltip(tester, 'Previous day');

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    expect(find.textContaining(notToday), findsOneWidget);
  });

  testWidgets('cannot move past today', (tester) async {
    await openScreen(tester);

    final next = find.widgetWithIcon(IconButton, Icons.chevron_right);
    expect(tester.widget<IconButton>(next).onPressed, isNull);

    await tapTooltip(tester, 'Previous day');
    expect(tester.widget<IconButton>(next).onPressed, isNotNull);
  });

  testWidgets('any day can be chosen from the calendar', (tester) async {
    await eventLog.add(
      EventType.feed,
      timestamp: DateTime(2026, 10, 15, 9),
      amount: 100,
    );
    await openScreen(tester);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Oct 15'), findsWidgets);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('the calendar highlights only days with events', (tester) async {
    await eventLog.add(EventType.feed, timestamp: DateTime(2026, 10, 15, 9));
    await eventLog.add(EventType.sleep, timestamp: DateTime(2026, 10, 20, 9));
    await eventLog.add(EventType.diaper, timestamp: DateTime(2026, 10, 25, 9));
    await eventLog.delete((await eventLog.currentEvents()).first);
    await openScreen(tester);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();

    Color? fillOf(String day) {
      final box = tester.widget<DecoratedBox>(
        find
            .ancestor(of: find.text(day), matching: find.byType(DecoratedBox))
            .first,
      );
      return (box.decoration as BoxDecoration).color;
    }

    expect(fillOf('15'), isNotNull);
    expect(fillOf('20'), isNotNull);
    expect(fillOf('16'), isNull);
    expect(fillOf('25'), isNull, reason: 'its only event was deleted');
  });

  testWidgets('the calendar moves between months but not into the future', (
    tester,
  ) async {
    await eventLog.add(EventType.feed, timestamp: DateTime(2026, 9, 15, 9));
    await openScreen(tester);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);

    final nextMonth = find.widgetWithIcon(IconButton, Icons.chevron_right).last;
    expect(tester.widget<IconButton>(nextMonth).onPressed, isNull);

    await tapTooltip(tester, 'Previous month');
    expect(find.text('September 2026'), findsOneWidget);

    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('future days in the calendar cannot be chosen', (tester) async {
    now = DateTime(2026, 10, 10, 12);
    await openScreen(tester);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();

    expect(find.text('October 2026'), findsOneWidget);
  });

  testWidgets('a day with no events says so', (tester) async {
    await eventLog.add(EventType.feed, amount: 100);
    await openScreen(tester);

    await tapTooltip(tester, 'Previous day');

    expect(find.text('Nothing logged on this day'), findsOneWidget);
  });

  testWidgets('editing an old event keeps it on that day', (tester) async {
    await eventLog.add(
      EventType.feed,
      timestamp: DateTime(2026, 10, 30, 9),
      amount: 100,
    );
    await openScreen(tester);
    await tapTooltip(tester, 'Previous day');

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(find.textContaining(notToday), findsOneWidget);
    await tester.enterText(find.byType(TextField), '150');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.textContaining('150.0 ml'), findsNWidgets(2));
  });

  testWidgets('moves on to the new day when reopened after midnight', (
    tester,
  ) async {
    now = DateTime(2026, 10, 31, 23);
    await eventLog.add(EventType.feed, amount: 100);
    await openScreen(tester);
    expect(find.byType(ListTile), findsOneWidget);

    now = DateTime(2026, 11, 1, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    expect(find.text('Nothing logged on this day'), findsOneWidget);
  });

  testWidgets('a failed save is shown to the user', (tester) async {
    await openScreen(tester);
    repository.failOnAppend = true;

    await openTab(tester, 'Diapers');
    await tapButton(tester, 'Log diaper');

    expect(find.textContaining('Something went wrong'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });
}
