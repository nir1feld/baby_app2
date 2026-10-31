import 'dart:io';

import 'package:baby_app2/data/baby_event.dart';
import 'package:baby_app2/data/sqflite_event_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  test('saves every field and reads it back', () async {
    final repository = await SqfliteEventRepository.open(
      databaseFactoryFfi,
      path,
    );
    final edit = BabyEvent(
      id: 'edit-1',
      type: EventType.edit,
      timestamp: DateTime.utc(2026, 10, 31, 8, 45),
      loggedAt: DateTime.utc(2026, 10, 31, 10),
      loggedBy: 'other parent',
      referencesId: 'feed-1',
    );

    await repository.append(feed);
    await repository.append(edit);

    final saved = await repository.allEvents();
    await repository.close();

    expect(saved.map((event) => event.toMap()), [feed.toMap(), edit.toMap()]);
    expect(saved.first.timestamp, feed.timestamp);
    expect(saved.last.amount, isNull);
    expect(saved.last.referencesId, 'feed-1');
  });

  test('events are still there after closing and reopening', () async {
    final first = await SqfliteEventRepository.open(databaseFactoryFfi, path);
    await first.append(feed);
    await first.close();

    final second = await SqfliteEventRepository.open(databaseFactoryFfi, path);
    final saved = await second.allEvents();
    await second.close();

    expect(saved.single.id, 'feed-1');
  });

  test('settings are saved, replaced and remembered', () async {
    final first = await SqfliteEventRepository.open(databaseFactoryFfi, path);
    expect(await first.readSetting('sheet'), isNull);

    await first.writeSetting('sheet', 'one');
    await first.writeSetting('sheet', 'two');
    await first.close();

    final second = await SqfliteEventRepository.open(databaseFactoryFfi, path);
    final value = await second.readSetting('sheet');
    await second.close();

    expect(value, 'two');
  });

  test('upgrading an older database keeps its events', () async {
    final older = await databaseFactoryFfi.openDatabase(
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
    await older.insert('events', feed.toMap());
    await older.close();

    final repository = await SqfliteEventRepository.open(
      databaseFactoryFfi,
      path,
    );
    await repository.writeSetting('sheet', 'one');
    final saved = await repository.allEvents();
    await repository.close();

    expect(saved.single.id, 'feed-1');
  });

  test('refuses a second event with the same ID', () async {
    final repository = await SqfliteEventRepository.open(
      databaseFactoryFfi,
      path,
    );
    await repository.append(feed);

    await expectLater(repository.append(feed), throwsA(anything));

    final saved = await repository.allEvents();
    await repository.close();
    expect(saved, hasLength(1));
  });
}
