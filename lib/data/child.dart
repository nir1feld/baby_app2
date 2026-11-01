import 'event_repository.dart';

/// One child's log on this phone, and the Google Sheet it syncs with, if any.
/// The app shows each one as a table with its own tab.
class Child {
  const Child({required this.id, required this.name, this.spreadsheetId});

  /// The table made for a phone's logs from before tables existed.
  const Child.first({String? spreadsheetId})
    : this(id: 'first', name: 'Baby', spreadsheetId: spreadsheetId);

  /// A table added with a sheet. The sheet's title replaces [name] when it
  /// first syncs. The spreadsheet ID is unique, so it also works as the ID.
  const Child.forSheet(String spreadsheetId, {String name = 'New table'})
    : this(id: spreadsheetId, name: name, spreadsheetId: spreadsheetId);

  /// Rebuilds a child from a stored row.
  factory Child.fromMap(Map<String, Object?> map) {
    return Child(
      id: map['id'] as String,
      name: map['name'] as String,
      spreadsheetId: map['spreadsheet_id'] as String?,
    );
  }

  final String id;
  final String name;
  final String? spreadsheetId;

  /// A copy of this child connected to [spreadsheetId].
  Child withSheet(String spreadsheetId) {
    return Child(id: id, name: name, spreadsheetId: spreadsheetId);
  }

  Map<String, Object?> toMap() {
    return {'id': id, 'name': name, 'spreadsheet_id': spreadsheetId};
  }
}

/// Where children are stored. A new phone has none.
abstract class ChildStore {
  /// Returns every child, oldest first.
  Future<List<Child>> children();

  /// Adds [child], or replaces the child with the same ID.
  Future<void> saveChild(Child child);

  /// Does nothing if the child was removed in the meantime.
  Future<void> renameChild(String id, String name);

  /// Removes a child and its logs from this phone.
  Future<void> removeChild(String id);

  /// The event log of one child.
  EventRepository eventsFor(String childId);
}
