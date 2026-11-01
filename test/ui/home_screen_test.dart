import 'package:baby_app2/data/baby_event.dart';
import 'package:baby_app2/data/event_log.dart';
import 'package:baby_app2/data/feed_amounts.dart';
import 'package:baby_app2/data/log_kind.dart';
import 'package:baby_app2/data/sync/sync_controller.dart';
import 'package:baby_app2/ui/home_screen.dart';
import 'package:baby_app2/ui/popups/log_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_event_repository.dart';
import '../fake_sync.dart';

const notToday = 'This is not today';
const secondLink = 'https://docs.google.com/spreadsheets/d/sheet-2/edit';

void main() {
  late FakeEventRepository repository;
  late FakeChildStore store;
  late FeedAmounts feedAmounts;
  late EventLog eventLog;
  late SyncController sync;
  late DateTime now;

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          eventLog: eventLog,
          sync: sync,
          popups: logPopups(feedAmounts),
        ),
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
    feedAmounts = FeedAmounts(FakeSettingsStore());
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

  group('feed amount buttons', () {
    Finder amountButton(String label) {
      return find.widgetWithText(ChoiceChip, label);
    }

    Future<void> tapAmountButton(WidgetTester tester, String label) async {
      await tester.tap(amountButton(label));
      await tester.pumpAndSettle();
    }

    Future<void> openFeedDialog(WidgetTester tester) async {
      await openScreen(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Log feed'));
      await tester.pumpAndSettle();
    }

    /// Last, because while editing the new amount field comes before it.
    String amountField(WidgetTester tester) {
      return tester
          .widget<TextField>(find.byType(TextField).last)
          .controller!
          .text;
    }

    testWidgets('a new feed starts with the default amount', (tester) async {
      await openFeedDialog(tester);

      expect(amountField(tester), '120');
    });

    testWidgets('with no amounts left, a new feed starts empty', (
      tester,
    ) async {
      for (final value in FeedAmounts.premade) {
        await feedAmounts.remove(value);
      }
      await openFeedDialog(tester);

      expect(amountField(tester), '');
      expect(find.text('No saved amounts'), findsOneWidget);
    });

    testWidgets('a button fills in the amount', (tester) async {
      await openFeedDialog(tester);

      await tapAmountButton(tester, '90');
      expect(amountField(tester), '90');

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.events.single.amount, 90);
    });

    testWidgets('the button matching the field shows as chosen', (
      tester,
    ) async {
      await openFeedDialog(tester);
      bool chosen(String label) {
        return tester.widget<ChoiceChip>(amountButton(label)).selected;
      }

      expect(chosen('120'), isTrue);

      await tester.enterText(find.byType(TextField).first, '60');
      await tester.pump();

      expect(chosen('120'), isFalse);
      expect(chosen('60'), isTrue);
    });

    testWidgets('only the default amount has a star', (tester) async {
      await openFeedDialog(tester);

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(
        find.descendant(
          of: amountButton('120'),
          matching: find.byIcon(Icons.star),
        ),
        findsOneWidget,
      );
    });

    testWidgets('editing an old feed keeps its amount', (tester) async {
      await eventLog.add(EventType.feed, timestamp: now, amount: 75);
      await openScreen(tester);

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(amountField(tester), '75');
    });

    testWidgets('diapers on an earlier day have no amount buttons', (
      tester,
    ) async {
      await openScreen(tester);
      await tapTooltip(tester, 'Previous day');
      await openTab(tester, 'Diapers');

      await tapButton(tester, 'Log diaper');

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byTooltip('Edit amounts'), findsNothing);
    });

    testWidgets('the list can only change after tapping edit', (tester) async {
      await openFeedDialog(tester);

      expect(find.text('Set as default'), findsNothing);
      expect(find.text('Remove'), findsNothing);
      expect(find.text('New amount (ml)'), findsNothing);

      await tapTooltip(tester, 'Edit amounts');

      expect(find.text('Set as default'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
      expect(find.text('New amount (ml)'), findsOneWidget);

      await tapTooltip(tester, 'Done editing amounts');

      expect(find.text('Set as default'), findsNothing);
    });

    testWidgets('while editing, a button highlights and does not fill in', (
      tester,
    ) async {
      await openFeedDialog(tester);
      await tapTooltip(tester, 'Edit amounts');

      await tapAmountButton(tester, '90');

      expect(amountField(tester), '120');
      expect(tester.widget<ChoiceChip>(amountButton('90')).selected, isTrue);
    });

    testWidgets('set as default needs a highlighted amount', (tester) async {
      await openFeedDialog(tester);
      await tapTooltip(tester, 'Edit amounts');
      OutlinedButton button(String label) {
        return tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, label),
        );
      }

      expect(button('Set as default').onPressed, isNull);
      expect(button('Remove').onPressed, isNull);

      await tapAmountButton(tester, '120');
      expect(button('Set as default').onPressed, isNull);
      expect(button('Remove').onPressed, isNotNull);

      await tapAmountButton(tester, '90');
      expect(button('Set as default').onPressed, isNotNull);
    });

    testWidgets('a new default is used next time', (tester) async {
      await openFeedDialog(tester);
      await tapTooltip(tester, 'Edit amounts');
      await tapAmountButton(tester, '90');

      await tester.tap(find.text('Set as default'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Log feed'));
      await tester.pumpAndSettle();

      expect(amountField(tester), '90');
    });

    testWidgets('an amount can be removed', (tester) async {
      await openFeedDialog(tester);
      await tapTooltip(tester, 'Edit amounts');
      await tapAmountButton(tester, '90');

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(amountButton('90'), findsNothing);
      expect(feedAmounts.values, [60, 120, 150]);
    });

    testWidgets('an amount can be added', (tester) async {
      await openFeedDialog(tester);
      await tapTooltip(tester, 'Edit amounts');

      await tester.enterText(find.byType(TextField).first, '75');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add'));
      await tester.pumpAndSettle();

      expect(amountButton('75'), findsOneWidget);
      expect(feedAmounts.values, [60, 75, 90, 120, 150]);
    });

    testWidgets('a repeated or invalid amount shows an error', (tester) async {
      await openFeedDialog(tester);
      await tapTooltip(tester, 'Edit amounts');

      for (final text in ['90', 'abc', '0', '']) {
        await tester.enterText(find.byType(TextField).first, text);
        await tester.tap(find.widgetWithText(OutlinedButton, 'Add'));
        await tester.pumpAndSettle();

        expect(find.text('Enter a new amount above 0'), findsOneWidget);
      }
      expect(feedAmounts.values, FeedAmounts.premade);
    });
  });

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
    expect(find.text('Oct 31, 12:00 PM, 60 ml'), findsOneWidget);

    await tester.tap(find.text('Baby'));
    await tester.pumpAndSettle();

    expect(find.text('Oct 31, 12:00 PM, 120 ml'), findsOneWidget);
    expect(find.text('Oct 31, 12:00 PM, 60 ml'), findsNothing);
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
    expect(find.textContaining('120 ml'), findsNWidgets(2));
  });

  testWidgets('a bad amount is refused and nothing is saved', (tester) async {
    await openScreen(tester);

    await logFeed(tester, 'lots');

    expect(find.text('Enter a number, or leave empty'), findsOneWidget);
    expect(repository.events, isEmpty);
  });

  testWidgets('a diaper logs with one tap', (tester) async {
    await openScreen(tester);

    await openTab(tester, 'Diapers');
    await tapButton(tester, 'Log diaper');

    expect(repository.events.single.type, EventType.diaper);
    expect(find.byType(AlertDialog), findsNothing);
  });

  group('the sleep popup', () {
    Future<void> openSleepDialog(WidgetTester tester) async {
      await openScreen(tester);
      await openTab(tester, 'Sleep');
      await tapButton(tester, 'Log sleep');
    }

    /// Types the finish, using the time picker's keyboard mode.
    Future<void> pickFinish(
      WidgetTester tester,
      String hour,
      String minute,
    ) async {
      await tester.tap(find.textContaining('Finish: '));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, hour);
      await tester.enterText(find.byType(TextField).last, minute);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    Future<void> openOldSleep(WidgetTester tester) async {
      await eventLog.add(EventType.sleep, timestamp: now, amount: 30);
      await openScreen(tester);
      await openTab(tester, 'Sleep');
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
    }

    testWidgets('asks for a start and a finish', (tester) async {
      await openSleepDialog(tester);

      expect(find.textContaining('Start: '), findsOneWidget);
      expect(find.text('Finish: not set'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('has none of the feed amount buttons', (tester) async {
      await openSleepDialog(tester);

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byTooltip('Edit amounts'), findsNothing);
    });

    testWidgets('saves the minutes from start to finish', (tester) async {
      await openSleepDialog(tester);

      await pickFinish(tester, '1', '45');
      expect(find.text('Finish: 1:45 PM'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.events.single.type, EventType.sleep);
      expect(repository.events.single.amount, 105);
      expect(find.textContaining('105 min'), findsNWidgets(2));
    });

    testWidgets('the finish may stay empty', (tester) async {
      await openSleepDialog(tester);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.events.single.amount, isNull);
    });

    testWidgets('editing a sleep shows its finish', (tester) async {
      await openOldSleep(tester);

      expect(find.text('Finish: 12:30 PM'), findsOneWidget);
    });

    testWidgets('saving an edit unchanged keeps the duration', (tester) async {
      await openOldSleep(tester);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.events.last.type, EventType.edit);
      expect(repository.events.last.amount, 30);
    });

    testWidgets('a finish can be cleared', (tester) async {
      await openOldSleep(tester);

      await tapTooltip(tester, 'Clear finish');
      expect(find.text('Finish: not set'), findsOneWidget);
      expect(find.byTooltip('Clear finish'), findsNothing);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.events.last.amount, isNull);
    });
  });

  testWidgets('the diaper popup has only a time', (tester) async {
    await openScreen(tester);
    await tapTooltip(tester, 'Previous day');
    await openTab(tester, 'Diapers');

    await tapButton(tester, 'Log diaper');

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  test('every kind of log has a popup', () {
    final popups = logPopups(feedAmounts);

    for (final kind in LogKind.values) {
      expect(popups, contains(kind));
    }
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
    expect(find.textContaining('150 ml'), findsNWidgets(2));
    expect(find.textContaining('120 ml'), findsNothing);
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
    expect(find.textContaining('200 ml'), findsNWidgets(2));
    expect(find.textContaining('100 ml'), findsNothing);

    await tapTooltip(tester, 'Previous day');

    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.textContaining('100 ml'), findsOneWidget);
    // The line at the top still shows the newest feed of all.
    expect(find.textContaining('Last feed:'), findsOneWidget);
    expect(find.textContaining('200 ml'), findsOneWidget);

    await tapTooltip(tester, 'Next day');

    expect(find.text('Today'), findsOneWidget);
    expect(find.textContaining('100 ml'), findsNothing);
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
    expect(find.textContaining('150 ml'), findsNWidgets(2));
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
