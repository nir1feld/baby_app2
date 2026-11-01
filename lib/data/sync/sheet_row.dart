import '../baby_event.dart';

/// The column titles, in the order the columns are stored.
const sheetHeader = [
  'id',
  'type',
  'timestamp',
  'logged_at',
  'logged_by',
  'amount',
  'references_id',
];

/// Turns [event] into a sheet row. Times are stored as UTC, in text that
/// people can read.
List<Object?> eventToRow(BabyEvent event) {
  return [
    event.id,
    event.type.name,
    event.timestamp.toUtc().toIso8601String(),
    event.loggedAt.toUtc().toIso8601String(),
    event.loggedBy,
    event.amount?.toString() ?? '',
    event.referencesId ?? '',
  ];
}

/// Reads an event from a sheet row, or returns null if the row isn't a valid
/// event. Sheets can be edited by hand, and this also skips the header row.
BabyEvent? eventFromRow(List<Object?> row) {
  // Sheets leaves out empty cells at the end of a row.
  String cell(int index) =>
      index < row.length ? (row[index]?.toString().trim() ?? '') : '';

  final id = cell(0);
  final type = EventType.values.asNameMap()[cell(1)];
  final timestamp = DateTime.tryParse(cell(2));
  final loggedAt = DateTime.tryParse(cell(3));
  if (id.isEmpty || type == null || timestamp == null || loggedAt == null) {
    return null;
  }

  final amountText = cell(5);
  final amount = double.tryParse(amountText);
  if (amountText.isNotEmpty && amount == null) return null;

  final referencesId = cell(6);
  final isChange = type == EventType.edit || type == EventType.delete;
  if (isChange && referencesId.isEmpty) return null;

  return BabyEvent(
    id: id,
    type: type,
    timestamp: timestamp,
    loggedAt: loggedAt,
    loggedBy: cell(4),
    amount: amount,
    referencesId: referencesId.isEmpty ? null : referencesId,
  );
}

/// Finds the spreadsheet ID in a Google Sheets link, or returns null.
String? spreadsheetIdFromLink(String link) {
  // RegExp(r'...') is a raw string: backslashes stay as they are.
  final match = RegExp(r'/spreadsheets/d/([a-zA-Z0-9_-]+)').firstMatch(link);
  return match?.group(1);
}
