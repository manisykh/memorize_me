# Android Release Signing

Run this from the repository root in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\android\setup_release_signing.ps1
```

The script creates local-only files:

```text
android/upload-keystore.jks
android/key.properties
```

These files are ignored by Git. Back them up securely. Losing the upload keystore can block future Play Store updates unless Play App Signing key reset is available.

After signing is configured, build the release bundle:

```powershell
flutter build appbundle --release
```

Google Picker uses the native Android authorization flow, so no Picker URL or
Picker-related `--dart-define` value is required for release builds.

Before Play Console upload, register the upload key SHA-1/SHA-256 in Google Cloud/Firebase if Google Sign-In is tested with a locally signed release build.
