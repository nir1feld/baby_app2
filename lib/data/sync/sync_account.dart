import 'remote_event_log.dart';

/// A sync problem with a message that can be shown to the user.
class SyncException implements Exception {
  const SyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The signed-in account that gives access to the remote log.
abstract class SyncAccount {
  /// The signed-in email address, or null if nobody is signed in.
  String? get email;

  /// Signs back in without showing anything, if a previous sign-in allows it.
  Future<void> restore();

  /// Shows the sign-in screens. Must follow a user action, such as a tap.
  Future<void> signIn();

  Future<void> signOut();

  /// Runs [action] with access to the log in the given spreadsheet, and
  /// throws a [SyncException] if that fails. `<T>` works as in C#: the
  /// result type is whatever [action] returns.
  Future<T> withLog<T>(
    String spreadsheetId,
    Future<T> Function(RemoteEventLog log) action,
  );
}
