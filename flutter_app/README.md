# YBS AI — Flutter V3

The Flutter application provides the same core Yangon YBS experience as the web app: offline-first route search, Burmese and English stop lookup, trip planning, OpenStreetMap maps, favorites, feedback, and arrival alerts.

## Implemented features

The application currently includes the following user-facing capabilities:

| Area            | Features                                                                                                                                                        |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Home            | Travel tips, notifications, nearby-stop discovery, and shortcuts to route search                                                                                |
| Route search    | Burmese or English stop search, autocomplete, duplicate-stop disambiguation, map selection, and GPS-based nearby stops                                          |
| Route planning  | Direct routes and transfer planning with forward stop-order validation, route details, saved trips, and Google Maps hand-off                                    |
| Route directory | Searchable route list with route details, stop lists, maps, favorites, ETA, predictions, and live map markers                                                   |
| Assistant       | Local Burmese/English stop extraction and offline route planning without requiring an AI API key                                                                |
| YBS New         | Implemented in the codebase but temporarily hidden from the Play Store build; re-enable with `AppConfig.showYbsNew` when the feature is ready                   |
| Favorites       | Favorite routes, favorite stops, and saved multi-step trips stored locally                                                                                      |
| Alerts          | In-app arrival alerts with vibration, local notifications, and Burmese text-to-speech; background alert support is configured for native platforms              |
| Settings        | Data refresh, cache information, notification setup, feedback, privacy, donation links, and application information; the app uses the original light theme only |

## App navigation

On route-detail maps, blue markers show recent community bus positions, the GPS marker shows your location, the tracking control follows live location, and tapping it again recenters the map on you. A separate bus control refreshes the reported positions.

The Play Store build currently uses five persistent tabs because YBS New is temporarily hidden:

```text
Home · Assistant · Routes · Find Route · Favorites
```

The YBS New implementation remains in `lib/pages/ybs_new_page.dart`. To restore it, change `showYbsNew` to `true` in `lib/config.dart`; the page, home shortcut, and bottom-navigation item are all wired through that flag and the tab indices automatically realign.

The app uses the original light-mode design only; the Display & Theme toggle has been removed because the previous theme switching caused low-contrast text rendering. Settings and detail screens are opened from the app bar or from their parent feature. The project does not use named routes; it uses an `IndexedStack` for the main tabs and `Navigator.push` for detail pages.

## Offline-first data flow

At startup, the app first attempts to load the locally cached route data. If no usable cache exists, it loads `assets/routes.bin`, decodes the base64 and XOR layers, decompresses the gzip payload with the cross-platform `archive` package, parses the route data, and stores the result locally. SQLite is used where supported for efficient direct-route queries, while the in-memory route finder remains the fallback.

This decoder is intentionally implemented without `dart:io` so the same route bundle works in Flutter web, Android, iOS, and desktop builds.

## Project structure

```text
flutter_app/
├── assets/
│   ├── routes.bin
│   └── icons/logo.png
├── lib/
│   ├── main.dart
│   ├── config.dart
│   ├── models.dart
│   ├── theme.dart
│   ├── data/
│   ├── pages/
│   ├── services/
│   ├── state/
│   ├── util/
│   └── widgets/
├── android/
│   ├── app/build.gradle.kts
│   ├── key.properties.example
│   └── app/src/main/AndroidManifest.xml
├── test/widget_test.dart
├── tools/build_routes_bundle.dart
├── pubspec.yaml
└── README.md
```

## Technology

| Layer                        | Technology                                                              |
| ---------------------------- | ----------------------------------------------------------------------- |
| Framework                    | Flutter 3.47.1, Dart 3.13+, Material 3                                  |
| State                        | `provider` and `ChangeNotifier`                                         |
| Networking                   | `http` and the Vercel REST API                                          |
| Route data                   | Encrypted bundled data, `SharedPreferences`, and SQLite where supported |
| Maps                         | `flutter_map`, OpenStreetMap tiles, and `latlong2`                      |
| Location                     | `geolocator`                                                            |
| Notifications                | `flutter_local_notifications`, `vibration`, and `flutter_tts`           |
| Background alerts            | `flutter_background_service` on native platforms                        |
| Cross-platform decompression | `archive`                                                               |

## Backend endpoints

The app uses the existing backend at `https://ybs-mm-v2.vercel.app` for network-enabled features:

```text
/api/bus-updates
/api/predictions
/api/bus-eta
/api/feedback
/api/notifications
/api/votes
/api/alert
```

Network failures are handled as non-fatal wherever possible so route search and cached data remain available offline. Device identifiers are used for anonymous community actions.

## Development setup

Install Flutter 3.47.1 or a compatible stable release, then run:

```bash
cd flutter_app
flutter pub get
flutter analyze
flutter test
flutter build web --release --no-wasm-dry-run
```

For a native development device:

```bash
flutter run
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
```

Android builds require the Android SDK and accepted Android licenses. iOS builds require macOS and Xcode. The Flutter web build does not require Chrome when using `flutter build web`; a Chrome installation is only needed for Chrome-device debugging.

## Android release signing

The Android module keeps local development convenient while preventing a Play Store build from silently using a debug key. If `flutter_app/android/key.properties` exists, release APK/AAB builds use the upload keystore configured there. If it does not exist, local release builds fall back to the debug key for testing only.

Copy `android/key.properties.example` to `android/key.properties`, create or obtain the upload keystore, and replace the placeholders. Do not commit either `key.properties` or the `.jks` file. For Play Console distribution, prefer an Android App Bundle (`.aab`) and configure Play App Signing in Google Play Console.

## Automated validation and Android artifacts

GitHub Actions runs the following checks for changes under `flutter_app/`:

```text
flutter pub get
flutter analyze
flutter test
flutter build web --release --no-wasm-dry-run
```

The Android release workflow additionally builds both artifacts:

```text
flutter build apk --release       # tester/sideload APK
flutter build appbundle --release # Play Store upload bundle
```

The workflow is defined in `.github/workflows/flutter-apk.yml`. It uploads the APK, AAB, and a `release-metadata.txt` file containing the version, signing mode, and SHA-256 hashes as the `yangon-ybs-guide-v3-android-release` artifact. Manual runs can require upload-key signing by setting the `play_store_release` input to `true`.

To enable signed CI builds, add these GitHub Actions secrets:

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
ANDROID_STORE_PASSWORD
```

The workflow intentionally fails a manually requested Play Store release when these secrets are missing. Ordinary pushes can still produce an unsigned-for-Play debug-signed artifact for functional testing, and the metadata file makes that status explicit.

## Route bundle maintenance

The source data and bundle-generation inputs are maintained outside the runtime package. When route data changes, regenerate `assets/routes.bin` with the project’s bundle tool and then run the full validation commands above. The XOR layer is obfuscation for casual inspection, not cryptographic protection.

## Known platform requirements

OpenStreetMap tiles require network access on first use and are subject to OpenStreetMap tile usage policy. GPS, notifications, text-to-speech, and background alerts require platform permissions. SQLite is unavailable on Flutter web, where the repository falls back to in-memory route searching.

## Release history

| Version  | Summary                                                                                                                                                  |
| -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `v3.3.2` | Removes the broken theme switch, restores the original light-only UI, removes theme preference persistence, and fixes low-contrast rendering             |
| `v3.3.1` | Temporarily hides YBS New for the Play Store build, aligns navigation indices, hardens startup initialization, and adds signed Android release artifacts |
| `v3.3.0` | Improved live tracking map controls, one-tap recentering, tracking guidance, and release documentation                                                   |
| `v3.2.0` | Persistent dark mode, polished display settings, accurate in-app release notes, and documentation refresh                                                |
| `v3.1.3` | Cross-platform route bundle decoding, startup recovery UI, dependency refresh, documentation refresh, and CI validation                                  |
| `v3.1.2` | Flutter web route loading fix                                                                                                                            |
| `v3.1.1` | Flutter dependency refresh for the current stable toolchain                                                                                              |

## License

This project is released under the MIT License.
