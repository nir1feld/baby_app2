import 'package:baby_app2/data/baby_event.dart';
import 'package:baby_app2/data/log_kind.dart';
import 'package:baby_app2/data/sync/sheet_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/sheets/v4.dart';

BabyEvent event(
  String id,
  EventType type, {
  DateTime? timestamp,
  double? amount,
}) {
  final time = timestamp ?? DateTime(2026, 10, 31, 8, 30);
  return BabyEvent(
    id: id,
    type: type,
    timestamp: time,
    loggedAt: time,
    loggedBy: 'parent@example.com',
    amount: amount,
  );
}

List<String?> texts(RowData row) {
  return row.values!.map((cell) {
    return cell.userEnteredValue?.stringValue;
  }).toList();
}

void main() {
  test('sheetDate counts days the way Google Sheets does', () {
    expect(sheetDate(DateTime(1899, 12, 31)), 1);
    expect(sheetDate(DateTime(2026, 11, 1)), 46327);
  });

  test('sheetDate ignores the time of day', () {
    expect(sheetDate(DateTime(2026, 11, 1, 23, 59)), 46327);
  });

  test('sheetTime is a fraction of a day', () {
    expect(sheetTime(DateTime(2026, 11, 1)), 0);
    expect(sheetTime(DateTime(2026, 11, 1, 12)), 0.5);
    expect(sheetTime(DateTime(2026, 11, 1, 6, 30)), closeTo(0.27083, 0.0001));
  });

  test('feeds have an amount column', () {
    final rows = summaryRows(LogKind.feed, const []);

    expect(texts(rows.single), ['Date', 'Time', 'Amount (ml)', 'Logged by']);
  });

  test('diapers have no number column', () {
    final rows = summaryRows(LogKind.diaper, const []);

    expect(texts(rows.single), ['Date', 'Time', 'Logged by']);
  });

  test('sleep has a start and a duration column', () {
    final rows = summaryRows(LogKind.sleep, const []);

    expect(texts(rows.single), [
      'Date',
      'Start',
      'Duration (min)',
      'Logged by',
    ]);
  });

  test('a sleep row holds its duration', () {
    final row = summaryRows(LogKind.sleep, [
      event('a', EventType.sleep, amount: 45),
    ]).last.values!;

    expect(row[2].userEnteredValue!.numberValue, 45);
  });

  test('a tab holds only its own kind of log, in the order given', () {
    final rows = summaryRows(LogKind.feed, [
      event('new', EventType.feed, timestamp: DateTime(2026, 11, 1)),
      event('diaper', EventType.diaper),
      event('old', EventType.feed, timestamp: DateTime(2026, 10, 31)),
    ]);

    final dates = rows.skip(1).map((row) {
      return row.values!.first.userEnteredValue!.numberValue;
    });
    expect(dates, [46327, 46326]);
  });

  test('a row holds real numbers, formatted for reading', () {
    final row = summaryRows(LogKind.feed, [
      event(
        'a',
        EventType.feed,
        timestamp: DateTime(2026, 11, 1, 12),
        amount: 120.5,
      ),
    ]).last.values!;

    expect(row[0].userEnteredValue!.numberValue, 46327);
    expect(row[0].userEnteredFormat!.numberFormat!.pattern, 'yyyy-mm-dd');
    expect(row[1].userEnteredValue!.numberValue, 0.5);
    expect(row[1].userEnteredFormat!.numberFormat!.pattern, 'hh:mm');
    expect(row[2].userEnteredValue!.numberValue, 120.5);
    expect(row[3].userEnteredValue!.stringValue, 'parent@example.com');
  });

  test('a feed with no amount leaves the cell empty', () {
    final row = summaryRows(LogKind.feed, [
      event('a', EventType.feed),
    ]).last.values!;

    expect(row[2].userEnteredValue, isNull);
  });

  test('times are shown in local time', () {
    final utc = DateTime.utc(2026, 11, 1, 12);
    final local = utc.toLocal();

    final row = summaryRows(LogKind.sleep, [
      event('a', EventType.sleep, timestamp: utc),
    ]).last.values!;

    expect(row[0].userEnteredValue!.numberValue, sheetDate(local));
    expect(row[1].userEnteredValue!.numberValue, sheetTime(local));
  });
}
