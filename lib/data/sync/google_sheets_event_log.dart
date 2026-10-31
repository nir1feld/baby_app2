import 'package:googleapis/sheets/v4.dart';

import '../baby_event.dart';
import 'remote_event_log.dart';
import 'sheet_row.dart';

/// Keeps the event log in the "Events" tab of a Google Sheet, one row per
/// event. The tab is added if it's missing.
class GoogleSheetsEventLog implements RemoteEventLog {
  GoogleSheetsEventLog(this._api, this._spreadsheetId);

  static const _tab = 'Events';
  static const _columns = '$_tab!A:G';

  final SheetsApi _api;
  final String _spreadsheetId;

  @override
  Future<List<BabyEvent>> fetchAll() async {
    await _ensureTabExists();
    final response = await _api.spreadsheets.values.get(
      _spreadsheetId,
      _columns,
    );
    // whereType keeps only the rows that aren't null.
    return (response.values ?? const [])
        .map(eventFromRow)
        .whereType<BabyEvent>()
        .toList();
  }

  @override
  Future<void> appendAll(List<BabyEvent> events) async {
    if (events.isEmpty) return;
    await _appendRows(events.map(eventToRow).toList());
  }

  Future<void> _ensureTabExists() async {
    final spreadsheet = await _api.spreadsheets.get(
      _spreadsheetId,
      $fields: 'sheets.properties.title',
    );
    final tabs = spreadsheet.sheets ?? const <Sheet>[];
    if (tabs.any((tab) => tab.properties?.title == _tab)) return;

    await _api.spreadsheets.batchUpdate(
      BatchUpdateSpreadsheetRequest(
        requests: [
          Request(
            addSheet: AddSheetRequest(properties: SheetProperties(title: _tab)),
          ),
        ],
      ),
      _spreadsheetId,
    );
    await _appendRows([sheetHeader]);
  }

  /// RAW stops Sheets from reformatting values, such as turning times into
  /// its own date format.
  Future<void> _appendRows(List<List<Object?>> rows) async {
    await _api.spreadsheets.values.append(
      ValueRange(values: rows),
      _spreadsheetId,
      _columns,
      valueInputOption: 'RAW',
      insertDataOption: 'INSERT_ROWS',
    );
  }
}
