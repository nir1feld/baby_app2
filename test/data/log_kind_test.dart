import 'package:baby_app2/data/baby_event.dart';
import 'package:baby_app2/data/log_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the tabs are in this order, in the app and the sheet', () {
    expect(LogKind.values.map((kind) => kind.title), [
      'Feeds',
      'Diapers',
      'Sleep',
    ]);
  });

  test('every kind can be found from its event type', () {
    for (final kind in LogKind.values) {
      expect(LogKind.of(kind.type), kind);
    }
  });

  test('edits and deletes are not kinds of log', () {
    expect(() => LogKind.of(EventType.edit), throwsStateError);
    expect(() => LogKind.of(EventType.delete), throwsStateError);
  });

  test('a measure has a title for the popup and the sheet', () {
    expect(LogKind.feed.measure!.title, 'Amount (ml)');
    expect(LogKind.sleep.measure!.title, 'Duration (min)');
  });

  test('a diaper records no number', () {
    expect(LogKind.diaper.measure, isNull);
  });
}
