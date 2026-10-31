\# Baby Tracker



Flutter app (Android first) for logging baby events: feeds, diapers, sleep.

Used by parents on several phones, each with their own Google account.



\## Commands

\- Run: `flutter run --dart-define-from-file=google_config.json` (the file is git-ignored; see README)

\- Test: `flutter test`

\- Lint: `flutter analyze`

\- Always run `flutter analyze` and `flutter test` before saying a task is done.



\## Architecture

\- Local-first: the app reads and writes a local database only. Sync is a

&#x20; separate layer behind an interface (`lib/data/sync/`) so the backend

&#x20; (currently Google Sheets) can be swapped later. Screens never wait on sync.

\- Data is an append-only event log. Each event has a unique ID, type,

&#x20; timestamp, optional amount, and who logged it. "Last feed" is derived

&#x20; from the newest feed event. Edits and deletes are new events that

&#x20; reference an ID, never in-place changes.



\## Conventions

\- Keep UI code and data code in separate folders.

\- Prefer simple, readable code over clever abstractions.

\- Ask before adding a new dependency, and say why it is needed.

\- I am new to Dart: explain unfamiliar syntax briefly when you use it.

\- I know C#: compare Flutter and Dart concepts to it when explaining.

\- Features go on their own branch. I merge to `main` myself.

\- Commit or push only when I ask.



\## Personal data (this repo is public)

Be careful with personal data. The repo is open source and I show it in job
interviews, so everything committed is public, including this file.

\- Never put personal data in tracked files, commit messages, PR text or test
  data: email addresses, real names, sheet links, Google client IDs, signing
  fingerprints (SHA-1), or anything logged about the baby. Tests use
  `example.com` addresses.

\- Real values stay in git-ignored files. `google_config.json` holds the Web
  client ID, and `google_config.example.json` is the public template.

\- Never commit a client secret (the app does not use one), `key.properties`,
  or a signing key.

\- Before every commit, check the staged files for these values.

\- `.gitignore` only protects files git is not tracking yet. If something
  personal was pushed, tell me straight away. Removing it means rewriting
  history, so ask first.

\- Older commits already show my personal email as the author. Leave that
  history alone unless I ask.



\## Project status (last updated 2026-10-31)

Built and working: event log in SQLite, Feeds/Diapers/Sleep tabs, today-only
view with day arrows, a custom calendar that shades days with logs, adding and
changing logs on earlier days with a "not today" warning, and Google sign-in
with two-way sync to a shared Google Sheet.

Tested on the emulator with a real Google account: sign-in, upload, and
restoring events to a fresh install from the sheet.

Not tested yet: a second parent on another account, and real offline use.

Next steps:

\- Test with a second parent. In Testing mode, their account must be listed as
  a test user on the Google consent screen.

\- Publish the app on the consent screen. In Testing mode, sign-ins expire
  after 7 days. I could not find the Publish app button.

\- Create a release signing key and add its SHA-1 as another Android OAuth
  client. Release APKs currently use the debug key.

\- The app is shared by APK, not a store. iPhones are not supported. Android
  developer verification is due to reach other countries in 2027, and a free
  hobbyist account may suit us.



\## Key decisions

\- The sheet syncs with the local table instead of replacing it, so logging is
  instant and works offline.

\- Sync exchanges missing rows by event ID. Bad rows in the sheet are skipped,
  and a row deleted from the sheet is restored by any phone that has it.

\- OAuth scope is `spreadsheets`, not `drive.file`: a shared sheet works by
  link, and `drive.file` would need a Picker that Flutter does not support.

\- Settings live in a SQLite table, to avoid another package.

\- The calendar is custom because Flutter's date picker cannot highlight
  individual days.

\- `lib/data` must not import Flutter UI code. `flutter/foundation.dart` is
  fine.



\## Lessons

\- Google access tokens do not refresh themselves, so each sync asks for a
  current one. Sign-in prompts need a user tap, so background sync failures
  only update the status icon.

\- `GoogleSheetsAccount` and `GoogleSheetsEventLog` have no automated tests.
  Any change to them needs a run against real Google.

\- `sqflite` does not run on the Windows or web targets. Use the Android
  emulator (`Medium_Phone_API_37.0`) to check the real app.

\- I may be using the emulator myself. Check before restarting the app or
  tapping, and never enter my Google password.

\- The Android package is `com.nir1feld.babylog`, tied to the Google OAuth
  client. Do not change it without updating that client.

