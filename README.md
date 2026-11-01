# BabyLog

A Flutter app (Android first) for parents to log feeds, diapers and sleep, and
share the log across phones through a Google Sheet.

- **Local first:** the app reads and writes a SQLite database on the phone, so
  logging is instant and works offline.
- **Append-only log:** edits and deletes are new events that refer to an
  earlier event, so phones can merge their logs by exchanging missing rows.
- **Swappable sync:** the app talks to the sheet through a small interface, so
  another backend can replace it.

## Running the app

```
flutter pub get
flutter run
```

The app works without any Google setup, but it won't sync.

## Setting up Google Sheets sync

1. In a Google Cloud project, enable the Google Sheets API and set up the OAuth
   consent screen with the `spreadsheets` scope.
2. Create an Android OAuth client with your package name and signing SHA-1.
   If you fork this project, change the package name in
   `android/app/build.gradle.kts` first.
3. Create a Web application OAuth client.
4. Copy `google_config.example.json` to `google_config.json`, which git ignores,
   and put the Web client ID in it.
5. Pass the file when you run or build the app:

   ```
   flutter run --dart-define-from-file=google_config.json
   flutter build apk --dart-define-from-file=google_config.json
   ```

In the app, create a table and paste the link to a blank Google Sheet that's
shared with the other parents as editors, then tap the cloud icon to sign in.
Each table has its own tab and sheet, and the tab takes the sheet's title. Use
the + button to add a table, and the X on a tab to remove it from the phone.

The sheet has a Feeds, a Diapers and a Sleep tab, with one row per log and real
dates and times, so charts and pivot tables work on them directly. The app
rewrites their first columns at every sync, so add your own formulas further
right or on another tab. A hidden Events tab holds the full log that phones
sync with. Leave it in place.

## Tests

```
flutter analyze
flutter test
```
