# Yangon YBS Guide — Flutter App

The Flutter application provides the same core Yangon YBS experience as the web app: offline-first route search, Burmese and English stop lookup, trip planning, OpenStreetMap maps, community bus updates, favorites, feedback, and arrival alerts.

## Implemented features

The application currently includes the following user-facing capabilities:

| Area | Features |
|---|---|
| Home | Travel tips, notifications, nearby-stop discovery, and shortcuts to route search |
| Route search | Burmese or English stop search, autocomplete, duplicate-stop disambiguation, map selection, and GPS-based nearby stops |
| Route planning | Direct routes and transfer planning with forward stop-order validation, route details, saved trips, and Google Maps hand-off |
| Route directory | Searchable route list with route details, stop lists, maps, favorites, bus updates, ETA, and predictions |
| Assistant | Local Burmese/English stop extraction and offline route planning without requiring an AI API key |
| YBS New | Community bus updates, update submission, route filtering, and voting |
| Favorites | Favorite routes, favorite stops, and saved multi-step trips stored locally |
| Alerts | In-app arrival alerts with vibration, local notifications, and Burmese text-to-speech; background alert support is configured for native platforms |
| Settings | Data refresh, cache information, notification setup, feedback, privacy, donation links, and application information |

## App navigation

The root shell uses six persistent tabs:

```text
Home · Assistant · YBS New · Routes · Find Route · Favorites
```

Settings and detail screens are opened from the app bar or from their parent feature. The project does not use named routes; it uses an `IndexedStack` for the main tabs and `Navigator.push` for detail pages.

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
│   │   ├── data_repository.dart
│   │   ├── route_finder.dart
│   │   ├── routes_crypto.dart
│   │   └── sqlite_routes.dart
│   ├── pages/
│   │   ├── assistant_page.dart
│   │   ├── favorites_page.dart
│   │   ├── find_route_page.dart
│   │   ├── home_page.dart
│   │   ├── map_picker_page.dart
│   │   ├── route_detail_page.dart
│   │   ├── route_plan_detail_page.dart
│   │   ├── routes_page.dart
│   │   ├── settings_page.dart
│   │   ├── stop_detail_page.dart
│   │   └── ybs_new_page.dart
│   ├── services/
│   ├── state/
│   ├── util/
│   └── widgets/
├── test/widget_test.dart
├── tools/build_routes_bundle.dart
├── pubspec.yaml
└── README.md
```

## Technology

| Layer | Technology |
|---|---|
| Framework | Flutter 3.47.1, Dart 3.13+, Material 3 |
| State | `provider` and `ChangeNotifier` |
| Networking | `http` and the Vercel REST API |
| Route data | Encrypted bundled data, `SharedPreferences`, and SQLite where supported |
| Maps | `flutter_map`, OpenStreetMap tiles, and `latlong2` |
| Location | `geolocator` |
| Notifications | `flutter_local_notifications`, `vibration`, and `flutter_tts` |
| Background alerts | `flutter_background_service` on native platforms |
| Cross-platform decompression | `archive` |

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
flutter build ios --release
```

Android builds require the Android SDK and accepted Android licenses. iOS builds require macOS and Xcode. The Flutter web build does not require Chrome when using `flutter build web`; a Chrome installation is only needed for Chrome-device debugging.

## Automated validation

GitHub Actions runs the following checks for changes under `flutter_app/`:

```text
flutter pub get
flutter analyze
flutter test
flutter build web --release --no-wasm-dry-run
```

The workflow is defined in `.github/workflows/flutter.yml`.

## Route bundle maintenance

The source data and bundle-generation inputs are maintained outside the runtime package. When route data changes, regenerate `assets/routes.bin` with the project’s bundle tool and then run the full validation commands above. The XOR layer is obfuscation for casual inspection, not cryptographic protection.

## Known platform requirements

OpenStreetMap tiles require network access on first use and are subject to OpenStreetMap tile usage policy. GPS, notifications, text-to-speech, and background alerts require platform permissions. SQLite is unavailable on Flutter web, where the repository falls back to in-memory route searching.

## Release history

| Version | Summary |
|---|---|
| `v3.1.3` | Cross-platform route bundle decoding, startup recovery UI, dependency refresh, documentation refresh, and CI validation |
| `v3.1.2` | Flutter web route loading fix |
| `v3.1.1` | Flutter dependency refresh for the current stable toolchain |

## License

This project is released under the MIT License.
