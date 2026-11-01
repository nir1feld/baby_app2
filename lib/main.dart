import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'data/event_log.dart';
import 'data/sqflite_event_repository.dart';
import 'data/sync/google_sheets_account.dart';
import 'data/sync/sync_controller.dart';
import 'google_config.dart';
import 'ui/home_screen.dart';

const _loggedByWhenSignedOut = 'this phone';

Future<void> main() async {
  // Needed because the database is opened before runApp.
  WidgetsFlutterBinding.ensureInitialized();

  final repository = await SqfliteEventRepository.open(
    databaseFactory,
    join(await getDatabasesPath(), 'baby_tracker.db'),
  );
  final eventLog = EventLog(repository, loggedBy: _loggedByWhenSignedOut);
  final sync = SyncController(
    local: repository,
    settings: repository,
    account: GoogleSheetsAccount(webClientId: googleWebClientId),
  );
  sync.addListener(() {
    eventLog.loggedBy = sync.email ?? _loggedByWhenSignedOut;
  });

  runApp(BabyLogApp(eventLog: eventLog, sync: sync));

  // Not awaited before runApp, so a slow network can't delay opening the app.
  await sync.start();
}

class BabyLogApp extends StatelessWidget {
  const BabyLogApp({super.key, required this.eventLog, required this.sync});

  final EventLog eventLog;
  final SyncController sync;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BabyLog',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: HomeScreen(eventLog: eventLog, sync: sync),
    );
  }
}
