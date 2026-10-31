import 'package:sqflite/sqflite.dart';

import 'baby_event.dart';
import 'event_repository.dart';

/// Stores events in a SQLite database on the device.
class SqfliteEventRepository implements EventRepository {
  SqfliteEventRepository._(this._database);

  final Database _database;

  /// Opens the database at [path], creating the table on first use.
  /// [factory] is passed in so tests can run SQLite on a PC.
  static Future<SqfliteEventRepository> open(
    DatabaseFactory factory,
    String path,
  ) async {
    final database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => db.execute('''
          CREATE TABLE events (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            logged_at INTEGER NOT NULL,
            logged_by TEXT NOT NULL,
            amount REAL,
            references_id TEXT
          )
        '''),
      ),
    );
    return SqfliteEventRepository._(database);
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
