import 'package:baby_app2/data/baby_event.dart';
import 'package:baby_app2/data/sync/remote_event_log.dart';
import 'package:baby_app2/data/sync/sync_account.dart';
import 'package:baby_app2/data/sync/sync_controller.dart';

/// Keeps the "sheet" in a list.
class FakeRemoteEventLog implements RemoteEventLog {
  final List<BabyEvent> events = [];

  /// When true, every request fails, like being offline.
  bool offline = false;

  /// When true, only uploads fail.
  bool failOnAppend = false;

  /// Runs in the middle of a fetch, for logging during a sync.
  Future<void> Function()? duringFetch;

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
    return action(remote);
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
