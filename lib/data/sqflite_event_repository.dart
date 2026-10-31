import 'package:sqflite/sqflite.dart';

import 'baby_event.dart';
import 'event_repository.dart';
import 'sync/sync_controller.dart';

/// Stores events and settings in a SQLite database on the device.
class SqfliteEventRepository implements EventRepository, SettingsStore {
  SqfliteEventRepository._(this._database);

  final Database _database;

  /// Opens the database at [path], creating the tables on first use and
  /// upgrading older databases. [factory] is passed in so tests can run
  /// SQLite on a PC.
  static Future<SqfliteEventRepository> open(
    DatabaseFactory factory,
    String path,
  ) async {
    final database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE events (
              id TEXT PRIMARY KEY,
              type TEXT NOT NULL,
              timestamp INTEGER NOT NULL,
              logged_at INTEGER NOT NULL,
              logged_by TEXT NOT NULL,
              amount REAL,
              references_id TEXT
            )
          ''');
          await _createSettingsTable(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createSettingsTable(db);
        },
      ),
    );
    return SqfliteEventRepository._(database);
  }

  static Future<void> _createSettingsTable(Database db) {
    return db.execute(
      'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
  }

  @override
  Future<String?> readSetting(String key) async {
    final rows = await _database.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  @override
  Future<void> writeSetting(String key, String value) async {
    await _database.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> append(BabyEvent event) async {
    await _database.insert('events', event.toMap());
  }

  @override
  Future<List<BabyEvent>> allEvents() async {
    final rows = await _database.query('events');
    return rows.map(BabyEvent.fromMap).toList();
  }

  Future<void> close() => _database.close();
}
