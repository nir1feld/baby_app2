---
title: BabyLog privacy policy
---

# BabyLog privacy policy

Last updated: 2 November 2026

BabyLog is a small open-source Android app for parents to log a baby's feeds,
diapers and sleep, and to share that log between their phones through a Google
Sheet. It is shared directly as an APK file, not through an app store. Its
source code is public at
[github.com/nir1feld/baby_app2](https://github.com/nir1feld/baby_app2).

## What the app stores

- **Logs you enter:** the kind of log, its date and time, its amount (ml for a
  feed, minutes for a sleep), and who logged it.
- **Who logged it:** the email address of the Google account signed in on
  that phone, or "this phone" if nobody is signed in.
- **Settings:** such as the feed amount buttons and the links of the sheets
  you added.

All of this is kept in the app's own database on your phone.

## Google sign-in and Google Sheets

When you sign in with Google, the app asks for permission to see, edit, create
and delete your Google Sheets spreadsheets. It uses that permission only for
the sheets you paste a link to in the app, and only to:

- read their rows, so a phone can pick up logs from other phones,
- add the tabs the app needs, and
- write your logs into them.

The app does not open, read or change any other spreadsheet, and it does not
use your Google data for anything else, such as advertising.

Your logs are written to the sheet you chose, which stays in the Google account
of whoever owns it. Anyone that sheet is shared with can read everything in it,
including the email address in "logged by". Google's handling of that sheet is
covered by [Google's privacy policy](https://policies.google.com/privacy).

## What the app does not do

- It has no servers of its own. Your data goes only to your phone and to the
  Google Sheets you link.
- It does not include analytics, advertising or crash reporting.
- It does not sell or share your data with anyone.

BabyLog's use and transfer of information received from Google APIs adheres
to the
[Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy),
including the Limited Use requirements.

## Deleting your data

- **On a phone:** remove a table with the × on its tab, or uninstall the app.
- **In Google Sheets:** delete the rows, tabs or the whole sheet in Google
  Sheets.
- **Access:** to stop the app reaching your sheets, remove BabyLog from
  [your Google account's connections](https://myaccount.google.com/connections).

## Children

The app records information about a baby that a parent enters. It is meant to
be used by parents, not by children.

## Changes and contact

Changes to this policy are published on this page. For questions, open an issue
at
[github.com/nir1feld/baby_app2/issues](https://github.com/nir1feld/baby_app2/issues).
