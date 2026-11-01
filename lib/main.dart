import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'data/event_log.dart';
import 'data/feed_amounts.dart';
import 'data/local_database.dart';
import 'data/log_kind.dart';
import 'data/sync/google_sheets_account.dart';
import 'data/sync/sync_controller.dart';
import 'google_config.dart';
import 'ui/home_screen.dart';
import 'ui/popups/log_popup.dart';

const _loggedByWhenSignedOut = 'this phone';

Future<void> main() async {
  // Needed because the database is opened before runApp.
  WidgetsFlutterBinding.ensureInitialized();

  final database = await LocalDatabase.open(
    databaseFactory,
    join(await getDatabasesPath(), 'baby_tracker.db'),
  );
  final sync = SyncController(
    store: database,
    settings: database,
    account: GoogleSheetsAccount(webClientId: googleWebClientId),
  );
  await sync.load();
  final eventLog = EventLog(
    sync.selectedEvents,
    loggedBy: _loggedByWhenSignedOut,
  );
  // Added before HomeScreen's listener, so the log is up to date when the
  // screen reloads after switching tabs.
  sync.addListener(() {
    eventLog.loggedBy = sync.email ?? _loggedByWhenSignedOut;
    eventLog.repository = sync.selectedEvents;
  });

  final feedAmounts = FeedAmounts(database);
  await feedAmounts.load();

  runApp(
    BabyLogApp(eventLog: eventLog, sync: sync, popups: logPopups(feedAmounts)),
  );

  // Not awaited before runApp, so a slow network can't delay opening the app.
  await sync.start();
}

class BabyLogApp extends StatelessWidget {
  const BabyLogApp({
    super.key,
    required this.eventLog,
    required this.sync,
    required this.popups,
  });

  final EventLog eventLog;
  final SyncController sync;
  final Map<LogKind, LogPopup> popups;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BabyLog',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: HomeScreen(eventLog: eventLog, sync: sync, popups: popups),
    );
  }
}
