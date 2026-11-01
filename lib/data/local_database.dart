import 'package:sqflite/sqflite.dart';

import 'baby_event.dart';
import 'child.dart';
import 'event_repository.dart';
import 'sync/sync_controller.dart';

/// Stores children, their events and settings in a SQLite database on the
/// device.
class LocalDatabase implements ChildStore, SettingsStore {
  LocalDatabase._(this._database);

  final Database _database;

  /// Opens the database at [path], creating the tables on first use and
  /// upgrading older databases. [factory] is passed in so tests can run
  /// SQLite on a PC.
  static Future<LocalDatabase> open(
    DatabaseFactory factory,
    String path,
  ) async {
    final database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          await _createEventsTable(db);
          await _createSettingsTable(db);
          await _createChildrenTable(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createSettingsTable(db);
          if (oldVersion < 3) await _moveEventsToFirstChild(db);
        },
      ),
    );
    return LocalDatabase._(database);
  }

  /// The same event can be in two children's sheets if a sheet was copied, so
  /// an ID only has to be unique within one child.
  static Future<void> _createEventsTable(Database db) {
    return db.execute('''
      CREATE TABLE events (
        child_id TEXT NOT NULL,
        id TEXT NOT NULL,
        type TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        logged_at INTEGER NOT NULL,
        logged_by TEXT NOT NULL,
        amount REAL,
        references_id TEXT,
        PRIMARY KEY (child_id, id)
      )
    ''');
  }

  static Future<void> _createSettingsTable(Database db) {
    return db.execute(
      'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
  }

  static Future<void> _createChildrenTable(Database db) {
    return db.execute('''
      CREATE TABLE children (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        spreadsheet_id TEXT
      )
    ''');
  }

  /// Before version 3 a phone had one log and one sheet. Both now belong to
  /// the first child, if there was anything to keep. SQLite can't change a
  /// primary key, so the events table is rebuilt. onUpgrade runs in a
  /// transaction, so this can't half finish.
  static Future<void> _moveEventsToFirstChild(Database db) async {
    const oldSheetKey = 'spreadsheet_id';
    final sheetRows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [oldSheetKey],
    );
    final spreadsheetId = sheetRows.isEmpty
        ? null
        : sheetRows.first['value'] as String;
    final child = Child.first(spreadsheetId: spreadsheetId);

    await _createChildrenTable(db);
    final anyEvents = (await db.query('events', limit: 1)).isNotEmpty;
    if (anyEvents || spreadsheetId != null) {
      await db.insert('children', child.toMap());
    }

    await db.execute('ALTER TABLE events RENAME TO old_events');
    await _createEventsTable(db);
    await db.execute(
      '''
      INSERT INTO events (child_id, id, type, timestamp, logged_at, logged_by,
                          amount, references_id)
      SELECT ?, id, type, timestamp, logged_at, logged_by, amount, references_id
      FROM old_events
      ''',
      [child.id],
    );
    await db.execute('DROP TABLE old_events');

    await db.delete('settings', where: 'key = ?', whereArgs: [oldSheetKey]);
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
  Future<List<Child>> children() async {
    final rows = await _database.query('children', orderBy: 'rowid');
    return rows.map(Child.fromMap).toList();
  }

  @override
  Future<void> saveChild(Child child) async {
    await _database.insert(
      'children',
      child.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> renameChild(String id, String name) async {
    await _database.update(
      'children',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> removeChild(String id) async {
    await _database.transaction((transaction) async {
      await transaction.delete(
        'events',
        where: 'child_id = ?',
        whereArgs: [id],
      );
      await transaction.delete('children', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  EventRepository eventsFor(String childId) {
    return _ChildEvents(_database, childId);
  }

  Future<void> close() => _database.close();
}

/// The events of one child. The leading _ makes the class private to this
/// file, like C#'s `private` on a nested class.
class _ChildEvents implements EventRepository {
  _ChildEvents(this._database, this._childId);

  final Database _database;
  final String _childId;

  @override
  Future<void> append(BabyEvent event) async {
    // ... copies the map's entries into this one, like C#'s collection spread.
    await _database.insert('events', {...event.toMap(), 'child_id': _childId});
  }

  @override
  Future<List<BabyEvent>> allEvents() async {
    final rows = await _database.query(
      'events',
      where: 'child_id = ?',
      whereArgs: [_childId],
      // Keeps the order they were saved in.
      orderBy: 'rowid',
    );
    return rows.map(BabyEvent.fromMap).toList();
  }
}
