/// Reads a number typed by the user, who may use a comma as the decimal point.
/// Returns null if it isn't a number.
double? parseAmount(String text) {
  return double.tryParse(text.trim().replaceAll(',', '.'));
}

/// Shows 120.0 as 120, and keeps 62.5 as it is.
String formatAmount(double amount) {
  return amount == amount.roundToDouble()
      ? amount.toInt().toString()
      : amount.toString();
}
