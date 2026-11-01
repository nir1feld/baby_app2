import 'package:flutter/material.dart';

import 'log_dialog_frame.dart';
import 'log_popup.dart';

/// A diaper only has a time.
class DiaperPopup extends LogPopup {
  const DiaperPopup();

  @override
  bool get logsWithOneTap => true;

  @override
  Widget build({
    required String title,
    required DateTime initialTime,
    double? initialAmount,
    String? warning,
  }) {
    return Builder(
      builder: (context) => LogDialogFrame(
        title: title,
        initialTime: initialTime,
        warning: warning,
        onSave: (time) {
          // Keeps an amount someone added to the sheet by hand.
          final LogDetails details = (time: time, amount: initialAmount);
          Navigator.of(context).pop(details);
        },
      ),
    );
  }
}
