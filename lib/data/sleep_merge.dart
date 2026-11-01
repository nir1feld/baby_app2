import 'baby_event.dart';

/// How to fold a new sleep into the sleeps it touches: [keep] is changed to
/// the combined start and minutes, and [remove] is deleted.
class SleepMerge {
  const SleepMerge({
    required this.keep,
    required this.start,
    required this.minutes,
    required this.remove,
  });

  final BabyEvent keep;
  final DateTime start;
  final double minutes;
  final List<BabyEvent> remove;
}

/// Works out the merge for a new sleep from [start] lasting [minutes], or
/// returns null if it overlaps nothing in [currentEvents]. Sleeps merge if
/// they overlap, or if one starts in the minute the other finishes. A sleep
/// with no duration yet counts as a single moment at its start.
SleepMerge? planSleepMerge(
  List<BabyEvent> currentEvents,
  DateTime start,
  double minutes,
) {
  final sleeps = currentEvents.where((event) => event.type == EventType.sleep);
  final merged = <BabyEvent>[];
  var from = _toMinute(start);
  var to = from.add(_minutes(minutes));

  // Repeats, because growing the span can reach another sleep.
  var grew = true;
  while (grew) {
    grew = false;
    for (final sleep in sleeps) {
      if (merged.contains(sleep)) continue;
      final sleepFrom = _toMinute(sleep.timestamp);
      final sleepTo = sleepFrom.add(_minutes(sleep.amount ?? 0));
      if (sleepFrom.isAfter(to) || sleepTo.isBefore(from)) continue;

      merged.add(sleep);
      if (sleepFrom.isBefore(from)) from = sleepFrom;
      if (sleepTo.isAfter(to)) to = sleepTo;
      grew = true;
    }
  }
  if (merged.isEmpty) return null;

  // The earliest sleep stays, so its row keeps its place in the log.
  merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return SleepMerge(
    keep: merged.first,
    start: from,
    minutes: to.difference(from).inMinutes.toDouble(),
    remove: merged.skip(1).toList(),
  );
}

Duration _minutes(double minutes) => Duration(minutes: minutes.round());

/// Drops the seconds, because the popup only sets whole minutes.
DateTime _toMinute(DateTime time) {
  final millis = time.millisecondsSinceEpoch;
  return DateTime.fromMillisecondsSinceEpoch(
    millis - millis % Duration.millisecondsPerMinute,
    isUtc: true,
  );
}
