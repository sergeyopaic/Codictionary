# Release guide

"The platform project exists" and "a release was verified" are different
things. This page records which is which.

## Platform matrix

Last checked: 2026-10-29, on Windows 11 with Flutter 3.35.4.

| Platform | Network permission | Release build | Request scenario in release | Status |
|---|---|---|---|---|
| Android | `INTERNET` in `src/main/AndroidManifest.xml` | ✅ `flutter build apk --release`; `aapt` shows package `com.sergey.codictionary` and `android.permission.INTERNET` | ❌ not run (no device or emulator available) | **Not verified on a device** |
| Web | not applicable | ✅ `flutter build web --release` | ✅ ran in a browser: OpenAI was reached (answered 429 `insufficient_quota`, shown as "out of credit"); DeepL is **blocked by CORS** | **Works, except translation** |
| Windows | not needed (desktop app, no sandbox) | ✅ `flutter build windows --release` | ❌ not run (it would write to the real `Documents\dictionary.json`) | **Build verified only** |
| Windows MSIX | `msix_config` capabilities not reviewed | ❌ not built | ❌ | **Not verified** |
| macOS | `com.apple.security.network.client` in both `.entitlements` files | ❌ needs a Mac | ❌ | **Not verified** |
| iOS | none needed for HTTPS | ❌ needs a Mac | ❌ | **Not verified** |
| Linux | not needed | ❌ no Linux toolchain | ❌ | **Not verified** |

Do not call a platform "supported" until its last two columns are ✅.

## Known limitations

- **Web translation.** DeepL does not allow requests from browsers (CORS), so
  auto-translate cannot work in the web build. The browser also cannot tell
  this apart from being offline, so the app says "Could not reach DeepL.
  Check your internet connection." The fix is the server gateway (T08/T09).
- **API keys inside the app.** `.env` is bundled as an asset, so anyone with
  a build can read the keys (e.g. `build/web/assets/.env`). Do not distribute
  builds with real keys before the gateway (T09) replaces them.
- **OpenAI balance.** As of 2026-10-29 the configured OpenAI project answers
  `insufficient_quota` (T11, owner task).

## Android

### Signing

Release builds are signed with the key described in `android/key.properties`.
That file and any `*.jks` / `*.keystore` are git-ignored; keep them out of
the repository.

1. Create an upload key once (store it outside the repository):

   ```bash
   keytool -genkey -v -keystore ~/codictionary-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Create `android/key.properties`:

   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=/absolute/path/to/codictionary-upload.jks
   ```

Without `key.properties` the release build falls back to the **debug key**
(so `flutter run --release` works locally) and Gradle logs a warning. Flutter
only shows it with `--verbose`, so check signing explicitly before
publishing:

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

The certificate must not be `CN=Android Debug`.

### Application id

The app id is `com.sergey.codictionary` on every platform (Android
`applicationId` and `namespace`, iOS and macOS bundle id, Linux
`APPLICATION_ID`, Windows MSIX identity). It cannot change after the first
store release.

Builds installed earlier under `com.example.codictionary` are a different app
to Android and macOS: they keep their own data, and the new build starts with
an empty dictionary there. Windows is not affected (data lives in
`Documents`).

### Before the first public release

- Set the app label: `android:label` is `codictionary` (lower case).

## Release checklist

- [ ] `flutter analyze --no-pub`, `dart format --output=none --set-exit-if-changed lib test`, `flutter test --no-pub` pass.
- [ ] No real keys in the build (see "API keys inside the app").
- [ ] Android: signed with the release key (`apksigner verify`), not the debug key.
- [ ] On each platform you ship: install the **release** build, add a word, and
      check that translation and the explanation work or show a clear error.
- [ ] Update the matrix above with what was actually checked and when.
