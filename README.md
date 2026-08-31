# Memorize Me

Memorize Me is a Flutter vocabulary study app with wordbooks, quizzes, SRS review, Google Sheets import, TTS, and AI-assisted study tools.

## Release Readiness

Primary application identifier:

- Android namespace/applicationId: `com.memorize.me`
- iOS/macOS bundle ID: `com.memorize.me`

Before publishing, regenerate platform credentials for the release identifiers and configure release signing.

Android release signing setup:

```powershell
powershell -ExecutionPolicy Bypass -File .\android\setup_release_signing.ps1
```

See `android/RELEASE_SIGNING.md` for details.

## Monetization foundation

The app launches with every feature free and no ads. Analytics, Remote Config,
and the `Free / Pro / Founding` entitlement foundation are documented in
`MONETIZATION_FOUNDATION.md`.

## Google Picker Setup

The Android app uses the Google Identity Services authorization client to open
Google Picker natively. It no longer sends OAuth access tokens to a hosted web
page and does not require `GOOGLE_PICKER_WEB_URL` at build or run time.

Required Google OAuth scope:

```text
https://www.googleapis.com/auth/drive.file
```

Enable Google Picker API and Google Sheets API in the same Google Cloud project as
the Android OAuth client. Register the package name and SHA certificate fingerprints
for debug, upload, and Play App Signing builds. Google Sheets API calls are limited
to files the user explicitly grants through Google Picker. Do not add
`spreadsheets.readonly` or `drive.readonly` unless the product intentionally moves
back to broad account-wide access and the corresponding OAuth verification is
completed.
