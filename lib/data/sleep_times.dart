/// The minutes from [start] until the clock next shows [hour]:[minute]. A
/// finish earlier in the day than the start means the sleep ended the next
/// day. Seconds are ignored, because the popup only sets whole minutes.
double sleepMinutes(DateTime start, {required int hour, required int minute}) {
  final from = DateTime(
    start.year,
    start.month,
    start.day,
    start.hour,
    start.minute,
  );
  var finish = DateTime(start.year, start.month, start.day, hour, minute);
  if (finish.isBefore(from)) {
    // DateTime rolls day 32 over into the next month.
    finish = DateTime(start.year, start.month, start.day + 1, hour, minute);
  }
  return finish.difference(from).inMinutes.toDouble();
}
