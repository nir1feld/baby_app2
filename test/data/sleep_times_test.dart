import 'package:baby_app2/data/sleep_times.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('counts the minutes between a start and a finish', () {
    final start = DateTime(2026, 11, 1, 13, 15);

    expect(sleepMinutes(start, hour: 14, minute: 45), 90);
  });

  test('a finish earlier in the day is on the next day', () {
    final start = DateTime(2026, 11, 1, 22, 30);

    expect(sleepMinutes(start, hour: 6, minute: 0), 450);
  });

  test('crossing the end of a month works', () {
    final start = DateTime(2026, 10, 31, 23, 0);

    expect(sleepMinutes(start, hour: 1, minute: 0), 120);
  });

  test('a finish equal to the start is no time at all', () {
    final start = DateTime(2026, 11, 1, 13, 15);

    expect(sleepMinutes(start, hour: 13, minute: 15), 0);
  });

  test('seconds in the start are ignored', () {
    final start = DateTime(2026, 11, 1, 13, 15, 40);

    expect(sleepMinutes(start, hour: 13, minute: 45), 30);
  });
}
