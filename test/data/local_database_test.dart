import 'dart:io';

import 'package:baby_app2/data/baby_event.dart';
import 'package:baby_app2/data/child.dart';
import 'package:baby_app2/data/local_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const eventsV1Table = '''
  CREATE TABLE events (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    logged_at INTEGER NOT NULL,
    logged_by TEXT NOT NULL,
    amount REAL,
    references_id TEXT
  )
''';

void main() {
  late Directory folder;
  late String path;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    folder = Directory.systemTemp.createTempSync('baby_tracker_test');
    path = join(folder.path, 'events.db');
  });

  tearDown(() => folder.deleteSync(recursive: true));

  final feed = BabyEvent(
    id: 'feed-1',
    type: EventType.feed,
    timestamp: DateTime.utc(2026, 10, 31, 8, 30),
    loggedAt: DateTime.utc(2026, 10, 31, 9),
    loggedBy: 'parent',
    amount: 120.5,
  );
  final firstId = const Child.first().id;

  test('saves every field and reads it back', () async {
    final database = await LocalDatabase.open(databaseFactoryFfi, path);
    final events = database.eventsFor(firstId);
    final edit = BabyEvent(
      id: 'edit-1',
      type: EventType.edit,
      timestamp: DateTime.utc(2026, 10, 31, 8, 45),
      loggedAt: DateTime.utc(2026, 10, 31, 10),
      loggedBy: 'other parent',
      referencesId: 'feed-1',
    );

    await events.append(feed);
    await events.append(edit);

    final saved = await events.allEvents();
    await database.close();

    expect(saved.map((event) => event.toMap()), [feed.toMap(), edit.toMap()]);
    expect(saved.first.timestamp, feed.timestamp);
    expect(saved.last.amount, isNull);
    expect(saved.last.referencesId, 'feed-1');
  });

  test('events are still there after closing and reopening', () async {
    final first = await LocalDatabase.open(databaseFactoryFfi, path);
    await first.eventsFor(firstId).append(feed);
    await first.close();

    final second = await LocalDatabase.open(databaseFactoryFfi, path);
    final saved = await second.eventsFor(firstId).allEvents();
    await second.close();

    expect(saved.single.id, 'feed-1');
  });

  test('settings are saved, replaced and remembered', () async {
    final first = await LocalDatabase.open(databaseFactoryFfi, path);
    expect(await first.readSetting('sheet'), isNull);

    await first.writeSetting('sheet', 'one');
    await first.writeSetting('sheet', 'two');
    await first.close();

    final second = await LocalDatabase.open(databaseFactoryFfi, path);
    final value = await second.readSetting('sheet');
    await second.close();

    expect(value, 'two');
  });

  test('a version 1 database keeps its events under the first child', () async {
    final older = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => db.execute(eventsV1Table),
      ),
    );
    await older.insert('events', feed.toMap());
    await older.close();

    final database = await LocalDatabase.open(databaseFactoryFfi, path);
    await database.writeSetting('sheet', 'one');
    final saved = await database.eventsFor(firstId).allEvents();
    final children = await database.children();
    await database.close();

    expect(saved.single.toMap(), feed.toMap());
    expect(children.single.spreadsheetId, isNull);
  });

  test('a version 2 database moves its sheet to the first child', () async {
    final older = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute(eventsV1Table);
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
        },
      ),
    );
    await older.insert('events', feed.toMap());
    await older.insert('settings', {
      'key': 'spreadsheet_id',
      'value': 'sheet-1',
    });
    await older.close();

    final database = await LocalDatabase.open(databaseFactoryFfi, path);
    final saved = await database.eventsFor(firstId).allEvents();
    final children = await database.children();
    final oldSetting = await database.readSetting('spreadsheet_id');
    await database.close();

    expect(saved.single.id, 'feed-1');
    expect(children.single.spreadsheetId, 'sheet-1');
    expect(oldSetting, isNull);
  });

  test('refuses a second event with the same ID', () async {
    final database = await LocalDatabase.open(databaseFactoryFfi, path);
    final events = database.eventsFor(firstId);
    await events.append(feed);

    await expectLater(events.append(feed), throwsA(anything));

    final saved = await events.allEvents();
    await database.close();
    expect(saved, hasLength(1));
  });

  test('a new database has no children', () async {
    final database = await LocalDatabase.open(databaseFactoryFfi, path);
    final children = await database.children();
    await database.close();

    expect(children, isEmpty);
  });

  test('an older database with nothing in it gets no child', () async {
    final older = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => db.execute(eventsV1Table),
      ),
    );
    await older.close();

    final database = await LocalDatabase.open(databaseFactoryFfi, path);
    final children = await database.children();
    await database.close();

    expect(children, isEmpty);
  });

  test('children are saved, renamed and kept in order', () async {
    final database = await LocalDatabase.open(databaseFactoryFfi, path);
    await database.saveChild(const Child.first());
    await database.saveChild(const Child.forSheet('sheet-2'));
    await database.renameChild('sheet-2', 'Second child');
    await database.renameChild('nobody', 'Ignored');

    final children = await database.children();
    await database.close();

    expect(children.map((child) => child.name), ['Baby', 'Second child']);
    expect(children.last.spreadsheetId, 'sheet-2');
  });

  test('each child has their own events, even with the same ID', () async {
    final database = await LocalDatabase.open(databaseFactoryFfi, path);
    await database.saveChild(const Child.forSheet('sheet-2'));

    await database.eventsFor(firstId).append(feed);
    expect(await database.eventsFor('sheet-2').allEvents(), isEmpty);

    await database.eventsFor('sheet-2').append(feed);
    final saved = await database.eventsFor('sheet-2').allEvents();
    await database.close();

    expect(saved.single.id, 'feed-1');
  });

  test('removing a child removes only their events', () async {
    final database = await LocalDatabase.open(databaseFactoryFfi, path);
    await database.saveChild(const Child.first());
    await database.saveChild(const Child.forSheet('sheet-2'));
    await database.eventsFor(firstId).append(feed);
    await database.eventsFor('sheet-2').append(feed);

    await database.removeChild('sheet-2');

    final children = await database.children();
    final kept = await database.eventsFor(firstId).allEvents();
    final removed = await database.eventsFor('sheet-2').allEvents();
    await database.close();

    expect(children.single.id, firstId);
    expect(kept, hasLength(1));
    expect(removed, isEmpty);
  });

  test('the last child can be removed', () async {
    final database = await LocalDatabase.open(databaseFactoryFfi, path);
    await database.saveChild(const Child.first(spreadsheetId: 'sheet-1'));
    await database.eventsFor(firstId).append(feed);

    await database.removeChild(firstId);

    final children = await database.children();
    final saved = await database.eventsFor(firstId).allEvents();
    await database.close();

    expect(children, isEmpty);
    expect(saved, isEmpty);
  });
}
