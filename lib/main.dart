import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'data/event_log.dart';
import 'data/sqflite_event_repository.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  // Needed because the database is opened before runApp.
  WidgetsFlutterBinding.ensureInitialized();

  final repository = await SqfliteEventRepository.open(
    databaseFactory,
    join(await getDatabasesPath(), 'baby_tracker.db'),
  );

  // To use a hosted backend later, swap `repository` here. Nothing else changes.
  // `loggedBy` is a placeholder until parents sign in with Google.
  final eventLog = EventLog(repository, loggedBy: 'this phone');

  runApp(BabyTrackerApp(eventLog: eventLog));
}

class BabyTrackerApp extends StatelessWidget {
  const BabyTrackerApp({super.key, required this.eventLog});

  final EventLog eventLog;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baby Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: HomeScreen(eventLog: eventLog),
    );
  }
}
