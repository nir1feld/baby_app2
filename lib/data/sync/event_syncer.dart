import '../baby_event.dart';
import '../event_repository.dart';
import 'remote_event_log.dart';

/// Makes the local and remote logs hold the same events. The logs are
/// append-only and IDs are unique, so this only has to copy whichever events
/// each side is missing. Running it twice changes nothing the second time.
class EventSyncer {
  EventSyncer(this._local, this._remote);

  final EventRepository _local;
  final RemoteEventLog _remote;

  /// Returns how many events were copied to this phone.
  Future<int> sync() async {
    final remote = await _remote.fetchAll();
    final local = await _local.allEvents();

    final localIds = local.map((event) => event.id).toSet();
    final remoteIds = <String>{};
    final toPull = <BabyEvent>[];
    for (final event in remote) {
      // add() returns false if the ID was already in the set.
      if (remoteIds.add(event.id) && !localIds.contains(event.id)) {
        toPull.add(event);
      }
    }

    // Saving locally comes first, so a failed upload loses nothing.
    for (final event in toPull) {
      await _local.append(event);
    }

    await _remote.appendAll(
      local.where((event) => !remoteIds.contains(event.id)).toList(),
    );
    return toPull.length;
  }
}
