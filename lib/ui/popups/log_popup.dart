import 'package:flutter/widgets.dart';

import '../../data/feed_amounts.dart';
import '../../data/log_kind.dart';
import 'diaper_popup.dart';
import 'feed_popup.dart';
import 'sleep_popup.dart';

/// What a popup closes with. A record is a small unnamed bundle of values.
typedef LogDetails = ({DateTime time, double? amount});

/// The popup of one kind of log. Each subclass owns its controls, so a feature
/// for one kind stays in that kind's file and the others never see it. Like a
/// C# abstract class: HomeScreen only knows this type.
abstract class LogPopup {
  const LogPopup();

  /// Today, this kind logs straight away, without opening the popup.
  bool get logsWithOneTap => false;

  /// What the amount of a new log starts as.
  double? get newAmount => null;

  /// Builds the popup, which closes with [LogDetails], or null if cancelled.
  Widget build({
    required String title,
    required DateTime initialTime,
    double? initialAmount,
    String? warning,
  });
}

/// The popup of each kind. Adding a popup takes a subclass and a line here.
Map<LogKind, LogPopup> logPopups(FeedAmounts feedAmounts) {
  return {
    LogKind.feed: FeedPopup(feedAmounts),
    LogKind.diaper: const DiaperPopup(),
    LogKind.sleep: const SleepPopup(),
  };
}
