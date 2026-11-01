/// Reads and saves settings on this phone. Settings are never synced.
abstract class SettingsStore {
  Future<String?> readSetting(String key);
  Future<void> writeSetting(String key, String value);
}
