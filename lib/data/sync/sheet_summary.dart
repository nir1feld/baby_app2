import 'package:googleapis/sheets/v4.dart';

import '../baby_event.dart';
import '../log_kind.dart';

/// The cell properties that writing a readable tab replaces.
const summaryCellFields =
    'userEnteredValue,'
    'userEnteredFormat.numberFormat,'
    'userEnteredFormat.textFormat.bold';

/// The rows of the readable tab of [kind], which holds what the log currently
/// says: edits are applied and deleted logs are left out. Rows are newest
/// first, with a header row on top. [currentEvents] must already be sorted
/// newest first.
List<RowData> summaryRows(LogKind kind, List<BabyEvent> currentEvents) {
  final measure = kind.measure;
  return [
    RowData(
      values: [
        _header('Date'),
        _header(kind.timeLabel),
        if (measure != null) _header(measure.title),
        _header('Logged by'),
      ],
    ),
    for (final event in currentEvents)
      if (event.type == kind.type)
        RowData(
          values: [
            _date(event.timestamp),
            _time(event.timestamp),
            if (measure != null) _amount(event.amount),
            CellData(
              userEnteredValue: ExtendedValue(stringValue: event.loggedBy),
            ),
          ],
        ),
  ];
}

/// Google Sheets counts dates as days since 30 December 1899. Storing real
/// dates, not text, is what lets charts and pivot tables group by day.
int sheetDate(DateTime localTime) {
  final day = DateTime.utc(localTime.year, localTime.month, localTime.day);
  return day.difference(DateTime.utc(1899, 12, 30)).inDays;
}

/// Google Sheets stores a time of day as a fraction of a day.
double sheetTime(DateTime localTime) {
  final seconds =
      localTime.hour * 3600 + localTime.minute * 60 + localTime.second;
  return seconds / Duration.secondsPerDay;
}

CellData _header(String text) {
  return CellData(
    userEnteredValue: ExtendedValue(stringValue: text),
    userEnteredFormat: CellFormat(textFormat: TextFormat(bold: true)),
  );
}

CellData _date(DateTime time) {
  return CellData(
    userEnteredValue: ExtendedValue(
      numberValue: sheetDate(time.toLocal()).toDouble(),
    ),
    userEnteredFormat: CellFormat(
      numberFormat: NumberFormat(type: 'DATE', pattern: 'yyyy-mm-dd'),
    ),
  );
}

CellData _time(DateTime time) {
  return CellData(
    userEnteredValue: ExtendedValue(numberValue: sheetTime(time.toLocal())),
    userEnteredFormat: CellFormat(
      numberFormat: NumberFormat(type: 'TIME', pattern: 'hh:mm'),
    ),
  );
}

/// A log may have no amount, and then the cell stays empty.
CellData _amount(double? amount) {
  return CellData(
    userEnteredValue: amount == null
        ? null
        : ExtendedValue(numberValue: amount),
  );
}
