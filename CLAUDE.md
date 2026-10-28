\# Baby Tracker



Flutter app (Android first) for logging baby events: feeds, diapers, sleep.

Used by parents on several phones, each with their own Google account.



\## Commands

\- Run: `flutter run`

\- Test: `flutter test`

\- Lint: `flutter analyze`

\- Always run `flutter analyze` and `flutter test` before saying a task is done.



\## Architecture

\- Local-first: the app reads and writes a local database only. Sync is a

&#x20; separate layer behind an interface so the backend (Google Drive or

&#x20; Firebase) can be swapped later. Do not add sync code unless asked.

\- Data is an append-only event log. Each event has a unique ID, type,

&#x20; timestamp, optional amount, and who logged it. "Last feed" is derived

&#x20; from the newest feed event. Edits and deletes are new events that

&#x20; reference an ID, never in-place changes.



\## Conventions

\- Keep UI code and data code in separate folders.

\- Prefer simple, readable code over clever abstractions.

\- Ask before adding a new dependency, and say why it is needed.

\- I am new to Dart: explain unfamiliar syntax briefly when you use it.

