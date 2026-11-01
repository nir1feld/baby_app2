import 'amount_text.dart';
import 'settings_store.dart';

/// The feed amounts offered as buttons, smallest first, and which one fills
/// in the amount of a new feed. Kept in this phone's settings and not synced,
/// so each parent can have their own.
class FeedAmounts {
  FeedAmounts(this._settings);

  static const _valuesKey = 'feed_amounts';
  static const _defaultKey = 'feed_amount_default';

  static const List<double> premade = [60, 90, 120, 150];
  static const double _premadeDefault = 120;

  final SettingsStore _settings;

  List<double> _values = premade;
  double? _defaultAmount = _premadeDefault;

  List<double> get values => _values;

  /// Null only when the list is empty.
  double? get defaultAmount => _defaultAmount;

  /// Loads the saved amounts. A phone that has saved none keeps the premade
  /// ones. An empty saved list stays empty, because the user removed them.
  Future<void> load() async {
    final savedValues = await _settings.readSetting(_valuesKey);
    if (savedValues == null) return;

    _values = savedValues
        .split(',')
        .map(parseAmount)
        .whereType<double>()
        .toList();
    final savedDefault = await _settings.readSetting(_defaultKey);
    final defaultAmount = parseAmount(savedDefault ?? '');
    _defaultAmount = _values.contains(defaultAmount)
        ? defaultAmount
        : _values.firstOrNull;
  }

  /// Returns false if [amount] isn't above zero or is already in the list.
  Future<bool> add(double amount) async {
    if (amount <= 0 || _values.contains(amount)) return false;
    _values = [..._values, amount]..sort();
    _defaultAmount ??= amount;
    await _save();
    return true;
  }

  /// Removing the default makes the smallest amount left the default.
  Future<void> remove(double amount) async {
    _values = _values.where((value) => value != amount).toList();
    if (_defaultAmount == amount) _defaultAmount = _values.firstOrNull;
    await _save();
  }

  Future<void> setDefault(double amount) async {
    if (!_values.contains(amount)) return;
    _defaultAmount = amount;
    await _save();
  }

  Future<void> _save() async {
    await _settings.writeSetting(_valuesKey, _values.join(','));
    await _settings.writeSetting(_defaultKey, _defaultAmount?.toString() ?? '');
  }
}
