import 'package:flutter/foundation.dart';

import '../child.dart';
import '../event_repository.dart';
import '../settings_store.dart';
import 'event_syncer.dart';
import 'sheet_row.dart';
import 'sync_account.dart';

enum SyncStatus { notSetUp, syncing, synced, failed }

/// Tracks the children, runs their syncs, and keeps the state for the UI.
/// ChangeNotifier is Flutter's version of INotifyPropertyChanged: listeners
/// run on notifyListeners().
class SyncController extends ChangeNotifier {
  SyncController({
    required this._store,
    required this._settings,
    required this._account,
    this._clock = DateTime.now,
  });

  static const _selectedChildKey = 'selected_child';

  final ChildStore _store;
  final SettingsStore _settings;
  final SyncAccount _account;
  final DateTime Function() _clock;

  bool _running = false;
  bool _runAgain = false;

  List<Child> _children = const [];
  String? _selectedChildId;
  SyncStatus _status = SyncStatus.notSetUp;
  String? _message;
  DateTime? _lastSynced;
  int _pulledCount = 0;

  String? get email => _account.email;
  List<Child> get children => _children;

  /// The table on screen, or null if there are none. The fallback covers the
  /// moment after a removal, before the next table is selected.
  Child? get selectedChild {
    for (final child in _children) {
      if (child.id == _selectedChildId) return child;
    }
    return _children.firstOrNull;
  }

  /// The selected table's events, or null if there are no tables.
  EventRepository? get selectedEvents {
    final child = selectedChild;
    return child == null ? null : _store.eventsFor(child.id);
  }

  /// ?. gives null if the left side is null, as in C#.
  String? get spreadsheetId => selectedChild?.spreadsheetId;
  SyncStatus get status => _status;

  /// What went wrong, if the last action failed.
  String? get message => _message;

  DateTime? get lastSynced => _lastSynced;

  /// Goes up whenever events arrive, so screens know to reload.
  int get pulledCount => _pulledCount;

  /// Loads the children and the selected child. This only reads the local
  /// database, so it's safe to wait for before showing the app.
  Future<void> load() async {
    _children = await _store.children();
    final saved = await _settings.readSetting(_selectedChildKey);
    final known = _children.any((child) => child.id == saved);
    _selectedChildId = known ? saved : _children.firstOrNull?.id;
  }

  /// Restores the sign-in and syncs.
  Future<void> start() async {
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

  /// Shows [childId]'s log.
  Future<void> selectChild(String childId) async {
    _selectedChildId = childId;
    notifyListeners();
    await _settings.writeSetting(_selectedChildKey, childId);
  }

  /// Adds a table and selects it. [name] may be empty if there is a [link],
  /// and [link] may be empty if there is a [name]. A sheet that already has a
  /// table just selects that table. Returns false if neither is given, or
  /// the link is invalid. Doesn't sync, so that a slow network can't hold up
  /// the screen: call [sync] afterwards.
  Future<bool> addTable({String name = '', String link = ''}) async {
    final Child child;
    if (link.trim().isEmpty) {
      if (name.trim().isEmpty) return false;
      final id = '${_clock().microsecondsSinceEpoch}';
      child = Child(id: id, name: name.trim());
    } else {
      final sheetId = spreadsheetIdFromLink(link);
      if (sheetId == null) return false;
      final existing = _tableWithSheet(sheetId);
      if (existing != null) {
        await selectChild(existing.id);
        return true;
      }
      child = name.trim().isEmpty
          ? Child.forSheet(sheetId)
          : Child.forSheet(sheetId, name: name.trim());
    }
    await _store.saveChild(child);
    await _reloadChildren();
    await selectChild(child.id);
    return true;
  }

  /// Links the sheet in [link] to the selected table and syncs. A sheet that
  /// already has a table just selects that table, so two tables' logs never
  /// mix. Returns false for an invalid link.
  Future<bool> connectSheet(String link) async {
    final selected = selectedChild;
    final id = spreadsheetIdFromLink(link);
    if (id == null || selected == null) return false;

    final existing = _tableWithSheet(id);
    if (existing != null) {
      await selectChild(existing.id);
    } else {
      await _store.saveChild(selected.withSheet(id));
      await _reloadChildren();
    }
    notifyListeners();
    await sync();
    return true;
  }

  Child? _tableWithSheet(String spreadsheetId) {
    for (final child in _children) {
      if (child.spreadsheetId == spreadsheetId) return child;
    }
    return null;
  }

  /// Removes a table and its logs from this phone. The Google Sheet is not
  /// touched.
  Future<void> removeTable(String id) async {
    await _store.removeChild(id);
    await _reloadChildren();
    final selected = selectedChild;
    if (selected != null) await selectChild(selected.id);
    // A failure may have been about the removed table.
    _status = SyncStatus.notSetUp;
    _message = null;
    notifyListeners();
    await sync();
  }

  Future<void> _reloadChildren() async {
    _children = await _store.children();
  }

  /// Syncs every child with a sheet, so a child that isn't on screen still
  /// uploads. Failures only update [status], because being offline is
  /// normal: the next sync picks up where this one stopped.
  Future<void> sync() async {
    final hasSheet = _children.any((child) => child.spreadsheetId != null);
    if (email == null || !hasSheet) {
      // Keep any sign-in error on screen until the next attempt.
      if (_status != SyncStatus.failed) _status = SyncStatus.notSetUp;
      notifyListeners();
      return;
    }
    // An event logged during a sync may have been missed, or a sheet may
    // have been added, so go again after.
    if (_running) {
      _runAgain = true;
      return;
    }

    _running = true;
    do {
      _runAgain = false;
      _status = SyncStatus.syncing;
      notifyListeners();

      // Read on each pass, so going again includes a newly connected sheet.
      final problem = await _syncAll(_children);
      if (problem == null) {
        _status = SyncStatus.synced;
        _message = null;
        _lastSynced = _clock();
      } else {
        _status = SyncStatus.failed;
        _message = problem;
      }
      notifyListeners();
    } while (_runAgain);
    _running = false;
  }

  /// Returns the first problem, or null if all went well. One failing sheet
  /// doesn't stop the others.
  Future<String?> _syncAll(List<Child> children) async {
    String? problem;
    for (final child in children) {
      if (child.spreadsheetId == null) continue;
      try {
        _pulledCount += await _syncChild(child);
      } on Exception catch (error) {
        // ??= assigns only if the left side is null, as in C#.
        problem ??= children.length > 1 ? '${child.name}: $error' : '$error';
      }
    }
    return problem;
  }

  Future<int> _syncChild(Child child) {
    return _account.withLog(child.spreadsheetId!, (remote) async {
      final events = _store.eventsFor(child.id);
      final pulled = await EventSyncer(events, remote).sync();
      final title = await remote.fetchTitle();
      if (title != child.name) {
        await _store.renameChild(child.id, title);
        await _reloadChildren();
      }
      return pulled;
    });
  }
}
