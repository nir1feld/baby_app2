import 'package:baby_app2/data/baby_event.dart';
import 'package:baby_app2/data/child.dart';
import 'package:baby_app2/data/event_repository.dart';
import 'package:baby_app2/data/sync/remote_event_log.dart';
import 'package:baby_app2/data/sync/sync_account.dart';
import 'package:baby_app2/data/sync/sync_controller.dart';

import 'fake_event_repository.dart';

/// Keeps children in a list. [firstEvents] is the first child's log, so tests
/// can look at it directly.
class FakeChildStore implements ChildStore {
  FakeChildStore(FakeEventRepository firstEvents) {
    _events[const Child.first().id] = firstEvents;
  }

  final List<Child> list = [const Child.first()];
  final Map<String, FakeEventRepository> _events = {};

  @override
  Future<List<Child>> children() async => List.of(list);

  @override
  Future<void> saveChild(Child child) async {
    final index = list.indexWhere((saved) => saved.id == child.id);
    if (index == -1) {
      list.add(child);
    } else {
      list[index] = child;
    }
  }

  @override
  Future<void> renameChild(String id, String name) async {
    final index = list.indexWhere((saved) => saved.id == id);
    if (index == -1) return;
    final child = list[index];
    list[index] = Child(id: id, name: name, spreadsheetId: child.spreadsheetId);
  }

  @override
  Future<void> removeChild(String id) async {
    list.removeWhere((child) => child.id == id);
    _events.remove(id);
  }

  @override
  EventRepository eventsFor(String childId) => events(childId);

  FakeEventRepository events(String childId) {
    return _events.putIfAbsent(childId, FakeEventRepository.new);
  }
}

/// Keeps the "sheet" in a list.
class FakeRemoteEventLog implements RemoteEventLog {
  FakeRemoteEventLog({this.title = 'Sheet title'});

  final List<BabyEvent> events = [];

  String title;

  /// When true, every request fails, like being offline.
  bool offline = false;

  /// When true, only uploads fail.
  bool failOnAppend = false;

  /// Runs in the middle of a fetch, for logging during a sync.
  Future<void> Function()? duringFetch;

  @override
  Future<String> fetchTitle() async => title;

  @override
  Future<List<BabyEvent>> fetchAll() async {
    if (offline) throw const SyncException('offline');
    final copy = List.of(events);
    await duringFetch?.call();
    duringFetch = null;
    return copy;
  }

  @override
  Future<void> appendAll(List<BabyEvent> newEvents) async {
    if (offline || failOnAppend) throw const SyncException('offline');
    events.addAll(newEvents);
  }
}

class FakeSyncAccount implements SyncAccount {
  FakeSyncAccount(this.remote, {this.email});

  final FakeRemoteEventLog remote;

  /// Sheets other than [remote], by spreadsheet ID.
  final Map<String, FakeRemoteEventLog> otherSheets = {};

  @override
  String? email;

  /// The address a sign-in or restore signs in as.
  String? restoredEmail;
  bool failSignIn = false;
  String? lastSpreadsheetId;

  @override
  Future<void> restore() async => email = restoredEmail;

  @override
  Future<void> signIn() async {
    if (failSignIn) throw const SyncException('sign-in failed');
    email = 'parent@example.com';
  }

  @override
  Future<void> signOut() async => email = null;

  @override
  Future<T> withLog<T>(
    String spreadsheetId,
    Future<T> Function(RemoteEventLog log) action,
  ) {
    lastSpreadsheetId = spreadsheetId;
    return action(otherSheets[spreadsheetId] ?? remote);
  }
}

class FakeSettingsStore implements SettingsStore {
  final Map<String, String> values = {};

  @override
  Future<String?> readSetting(String key) async => values[key];

  @override
  Future<void> writeSetting(String key, String value) async {
    values[key] = value;
  }
}
