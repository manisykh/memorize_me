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

The Android app opens Google Picker in an external browser and receives the selected spreadsheet through this deep link:

```text
memorizeme://picker
```

Host `picker_hosting/google_picker.html` on HTTPS, then replace these constants in the hosted file:

```text
REPLACE_WITH_WEB_OAUTH_CLIENT_ID
REPLACE_WITH_PICKER_API_KEY
```

Run locally with:

```powershell
flutter run --dart-define=GOOGLE_PICKER_WEB_URL=https://your-host.example/google_picker.html
```

Required Google OAuth scopes:

```text
https://www.googleapis.com/auth/spreadsheets.readonly
https://www.googleapis.com/auth/drive.file
```

Do not add `drive.readonly` unless the app is intentionally moving back to full Drive read access.
