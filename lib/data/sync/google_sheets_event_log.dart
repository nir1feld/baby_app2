import 'dart:math';

import 'package:googleapis/sheets/v4.dart';

import '../baby_event.dart';
import '../log_kind.dart';
import 'remote_event_log.dart';
import 'sheet_row.dart';
import 'sheet_summary.dart';

/// Keeps the full event log in a hidden "Events" tab, one row per event,
/// including edits and deletes, because that's how phones exchange changes.
/// People read one tab per [LogKind], which the app rewrites from the log.
/// Missing tabs are added.
class GoogleSheetsEventLog implements RemoteEventLog {
  GoogleSheetsEventLog(this._api, this._spreadsheetId);

  static const _tab = 'Events';
  static const _columns = '$_tab!A:G';

  final SheetsApi _api;
  final String _spreadsheetId;

  /// The sheet's tabs by title, read once per sync.
  Map<String, SheetProperties>? _tabs;

  @override
  Future<String> fetchTitle() async {
    final spreadsheet = await _api.spreadsheets.get(
      _spreadsheetId,
      $fields: 'properties.title',
    );
    return spreadsheet.properties?.title ?? 'Untitled sheet';
  }

  @override
  Future<List<BabyEvent>> fetchAll() async {
    await _prepareTabs();
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

  /// Sent as one request, so a reader never sees a half-written tab.
  @override
  Future<void> writeSummary(List<BabyEvent> currentEvents) async {
    final tabs = _tabs ?? await _prepareTabs();
    final requests = <Request>[];
    for (final kind in LogKind.values) {
      final tab = tabs[kind.title]!;
      final rows = summaryRows(kind, currentEvents);

      final missingRows = rows.length - (tab.gridProperties?.rowCount ?? 0);
      if (missingRows > 0) {
        requests.add(
          Request(
            appendDimension: AppendDimensionRequest(
              sheetId: tab.sheetId,
              dimension: 'ROWS',
              length: missingRows,
            ),
          ),
        );
      }

      // Cells in the range that rows don't cover are cleared, so logs that
      // were deleted disappear. Columns further right are left alone, so
      // people can add their own formulas there.
      requests.add(
        Request(
          updateCells: UpdateCellsRequest(
            fields: summaryCellFields,
            rows: rows,
            range: GridRange(
              sheetId: tab.sheetId,
              startColumnIndex: 0,
              endColumnIndex: rows.first.values!.length,
              startRowIndex: 0,
              endRowIndex: max(rows.length, tab.gridProperties?.rowCount ?? 0),
            ),
          ),
        ),
      );
    }
    await _batchUpdate(requests);
  }

  /// Adds the tabs that are missing and hides the log. The readable tabs are
  /// added first, because Sheets refuses to hide its only visible tab.
  Future<Map<String, SheetProperties>> _prepareTabs() async {
    var tabs = await _readTabs();
    final logIsMissing = !tabs.containsKey(_tab);
    final requests = [
      for (final kind in LogKind.values)
        if (!tabs.containsKey(kind.title)) _addSummaryTab(kind.title),
      if (logIsMissing) _addHiddenLogTab(),
      if (!logIsMissing && tabs[_tab]!.hidden != true)
        _hide(tabs[_tab]!.sheetId),
    ];

    if (requests.isNotEmpty) {
      await _batchUpdate(requests);
      tabs = await _readTabs();
    }
    if (logIsMissing) await _appendRows([sheetHeader]);
    _tabs = tabs;
    return tabs;
  }

  Future<Map<String, SheetProperties>> _readTabs() async {
    final spreadsheet = await _api.spreadsheets.get(
      _spreadsheetId,
      $fields:
          'sheets.properties(sheetId,title,hidden,gridProperties.rowCount)',
    );
    return {
      for (final tab in spreadsheet.sheets ?? const <Sheet>[])
        if (tab.properties?.title != null)
          tab.properties!.title!: tab.properties!,
    };
  }

  Request _addSummaryTab(String title) {
    return Request(
      addSheet: AddSheetRequest(
        properties: SheetProperties(
          title: title,
          // Keeps the header row in view when scrolling.
          gridProperties: GridProperties(frozenRowCount: 1),
        ),
      ),
    );
  }

  Request _addHiddenLogTab() {
    return Request(
      addSheet: AddSheetRequest(
        properties: SheetProperties(title: _tab, hidden: true),
      ),
    );
  }

  Request _hide(int? sheetId) {
    return Request(
      updateSheetProperties: UpdateSheetPropertiesRequest(
        properties: SheetProperties(sheetId: sheetId, hidden: true),
        fields: 'hidden',
      ),
    );
  }

  Future<void> _batchUpdate(List<Request> requests) async {
    await _api.spreadsheets.batchUpdate(
      BatchUpdateSpreadsheetRequest(requests: requests),
      _spreadsheetId,
    );
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
