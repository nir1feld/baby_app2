import 'package:baby_app2/data/baby_event.dart';
import 'package:baby_app2/data/event_log.dart';
import 'package:baby_app2/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_event_repository.dart';

void main() {
  late FakeEventRepository repository;

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(eventLog: EventLog(repository, loggedBy: 'parent')),
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

  setUp(() => repository = FakeEventRepository());

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

  testWidgets('a failed save is shown to the user', (tester) async {
    await openScreen(tester);
    repository.failOnAppend = true;

    await openTab(tester, 'Diapers');
    await tapButton(tester, 'Log diaper');

    expect(find.textContaining('Something went wrong'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });
}
