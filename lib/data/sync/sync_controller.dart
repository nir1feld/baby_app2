import 'package:flutter/foundation.dart';

import '../event_repository.dart';
import 'event_syncer.dart';
import 'sheet_row.dart';
import 'sync_account.dart';

enum SyncStatus { notSetUp, syncing, synced, failed }

/// Reads and saves settings, so the sheet is remembered between app runs.
abstract class SettingsStore {
  Future<String?> readSetting(String key);
  Future<void> writeSetting(String key, String value);
}

/// Runs syncs and tracks their state for the UI. ChangeNotifier is Flutter's
/// version of INotifyPropertyChanged: listeners run on notifyListeners().
class SyncController extends ChangeNotifier {
  SyncController({
    required this._local,
    required this._settings,
    required this._account,
    this._clock = DateTime.now,
  });

  static const _sheetKey = 'spreadsheet_id';

  final EventRepository _local;
  final SettingsStore _settings;
  final SyncAccount _account;
  final DateTime Function() _clock;

  bool _running = false;
  bool _runAgain = false;

  String? _spreadsheetId;
  SyncStatus _status = SyncStatus.notSetUp;
  String? _message;
  DateTime? _lastSynced;
  int _pulledCount = 0;

  String? get email => _account.email;
  String? get spreadsheetId => _spreadsheetId;
  SyncStatus get status => _status;

  /// What went wrong, if the last action failed.
  String? get message => _message;

  DateTime? get lastSynced => _lastSynced;

  /// Goes up whenever events arrive, so screens know to reload.
  int get pulledCount => _pulledCount;

  /// Loads the saved sheet, restores the sign-in, and syncs.
  Future<void> start() async {
    _spreadsheetId = await _settings.readSetting(_sheetKey);
    try {
      await _account.restore();
    } on Exception {
      // The user can still sign in from the Google Sheet screen.
    }
    notifyListeners();
    await sync();
  }

  Future<void> signIn() async {
    _message = null;
    try {
      await _account.signIn();
    } on Exception catch (error) {
      _status = SyncStatus.failed;
      _message = '$error';
      notifyListeners();
      return;
    }
    notifyListeners();
    await sync();
  }

  Future<void> signOut() async {
    await _account.signOut();
    _status = SyncStatus.notSetUp;
    _message = null;
    notifyListeners();
  }

  /// Saves the sheet in [link] and syncs. Returns false for an invalid link.
  Future<bool> connectSheet(String link) async {
    final id = spreadsheetIdFromLink(link);
    if (id == null) return false;
    await _settings.writeSetting(_sheetKey, id);
    _spreadsheetId = id;
    notifyListeners();
    await sync();
    return true;
  }

  /// Syncs if the app is set up. Failures only update [status], because
  /// being offline is normal: the next sync picks up where this one stopped.
  Future<void> sync() async {
    if (email == null || _spreadsheetId == null) {
      // Keep any sign-in error on screen until the next attempt.
      if (_status != SyncStatus.failed) _status = SyncStatus.notSetUp;
      notifyListeners();
      return;
    }
    // An event logged during a sync may have been missed, or the sheet may
    // have changed, so go again after.
    if (_running) {
      _runAgain = true;
      return;
    }

    _running = true;
    do {
      _runAgain = false;
      _status = SyncStatus.syncing;
      notifyListeners();
      try {
        // Read on each pass, so going again uses a newly connected sheet.
        // The ! says "not null here", like C#'s null-forgiving operator, but
        // Dart also checks it when the app runs.
        final pulled = await _account.withLog(
          _spreadsheetId!,
          (remote) => EventSyncer(_local, remote).sync(),
        );
        _pulledCount += pulled;
        _status = SyncStatus.synced;
        _message = null;
        _lastSynced = _clock();
      } on Exception catch (error) {
        _status = SyncStatus.failed;
        _message = '$error';
      }
      notifyListeners();
    } while (_runAgain);
    _running = false;
  }
}
