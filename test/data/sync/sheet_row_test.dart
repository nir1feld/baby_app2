import 'package:baby_app2/data/baby_event.dart';
import 'package:baby_app2/data/sync/sheet_row.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final feed = BabyEvent(
    id: 'feed-1',
    type: EventType.feed,
    timestamp: DateTime.utc(2026, 10, 31, 8, 30),
    loggedAt: DateTime.utc(2026, 10, 31, 9),
    loggedBy: 'parent@example.com',
    amount: 120.5,
  );

  final edit = BabyEvent(
    id: 'edit-1',
    type: EventType.edit,
    timestamp: DateTime.utc(2026, 10, 31, 8, 45),
    loggedAt: DateTime.utc(2026, 10, 31, 10),
    loggedBy: 'other@example.com',
    referencesId: 'feed-1',
  );

  List<Object?> validRow() => eventToRow(feed);

  test('events survive being written to a row and read back', () {
    for (final event in [feed, edit]) {
      final read = eventFromRow(eventToRow(event));
      expect(read?.toMap(), event.toMap());
    }
  });

  test('times are stored as readable UTC text', () {
    expect(eventToRow(feed)[2], '2026-10-31T08:30:00.000Z');
  });

  test('the row has the same columns as the header', () {
    expect(eventToRow(feed), hasLength(sheetHeader.length));
  });

  test('reads rows where Sheets dropped the empty cells at the end', () {
    final row = validRow().sublist(0, 5);

    final read = eventFromRow(row);

    expect(read?.id, 'feed-1');
    expect(read?.amount, isNull);
    expect(read?.referencesId, isNull);
  });

  test('reads an amount that Sheets returned as a number', () {
    final row = validRow();
    row[5] = 90;

    expect(eventFromRow(row)?.amount, 90);
  });

  test('skips the header row', () {
    expect(eventFromRow(sheetHeader), isNull);
  });

  test('skips an empty row', () {
    expect(eventFromRow([]), isNull);
  });

  test('skips rows damaged by hand', () {
    List<Object?> damaged(int column, Object? value) =>
        validRow()..[column] = value;

    expect(eventFromRow(damaged(0, '')), isNull, reason: 'no ID');
    expect(eventFromRow(damaged(1, 'bath')), isNull, reason: 'unknown type');
    expect(eventFromRow(damaged(2, 'noon')), isNull, reason: 'bad time');
    expect(eventFromRow(damaged(3, '')), isNull, reason: 'no logged time');
    expect(eventFromRow(damaged(5, 'lots')), isNull, reason: 'bad amount');
  });

  test('skips an edit or delete that refers to nothing', () {
    final row = eventToRow(edit)..[6] = '';

    expect(eventFromRow(row), isNull);
  });

  test('finds the spreadsheet ID in a link', () {
    const link =
        'https://docs.google.com/spreadsheets/d/1aB_c-D2/edit?gid=0#gid=0';

    expect(spreadsheetIdFromLink(link), '1aB_c-D2');
  });

  test('rejects text that is not a sheet link', () {
    expect(spreadsheetIdFromLink(''), isNull);
    expect(spreadsheetIdFromLink('https://example.com/sheet'), isNull);
  });
}
