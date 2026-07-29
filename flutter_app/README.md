# YBS Guide (Yangon Bus Service)

Offline-first Flutter app for navigating Yangon's bus network with Burmese-language AI assistance, community updates, and live arrival alerts.

## Features

### Navigation & Route Planning
- **Find Route** — Enter start/end stops (Burmese or English) with autocomplete and disambiguation; supports map picker and "Near Me" GPS
- **AI Assistant** — Burmese NLP chat interface ("A ကနေ B ကို") that extracts stops, fuzzy-resolves names, and runs BFS routing
- **Route Browsing** — Full list of YBS routes, searchable by route number, operator, or township; stop-by-stop details with OSM map
- **Offline BFS Routing** — 2-transfer max routing with shortest-forward-span ranking; works fully offline after first launch
- **Trip Re-planning** — Adjust route plans mid-journey from any step

### Live Tracking & Alerts
- **Arrival Alerts** — In-app vibration + Burmese TTS notification when bus nears selected stop
- **Background Alerts** — Foreground service polls GPS + server while app is closed; fires full-screen intent, wakes screen, speaks arrival in Burmese
- **ETA & Predictions** — Live ETA and prediction data from backend

### Community Features
- **YBS New Feed** — Real-time community bus updates (started, reached, road closed, delays, etc.)
- **Voting** — Upvote/downvote community updates
- **Post Update** — Share live bus status via update sheet

### Favorites & Personalization
- **Saved Trips** — Favorite multi-step route plans for quick access
- **Favorite Stops & Routes** — Star frequently used stops and routes
- **Travel Tips** — Quick tips for Yangon bus travel on home screen
- **Recent Searches** — History of recent route lookups
- **Leaderboard & Rewards** — Community ranking by contribution points, badge milestones, reward redemption (requires device ID)

### Settings & Utilities
- **Data Sync** — Refresh route bundle from assets and rebuild SQLite cache
- **Notification Setup** — Guided setup for background alert service and notification permissions
- **Privacy & Feedback** — Privacy policy, feedback dialog, donation (KPay/Wave)
- **About / What's New** — App info and changelog

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.x, Dart 3.12+, Material 3 |
| **State Management** | `provider` (`ChangeNotifier`) |
| **Networking** | `http` (REST client → Vercel backend) |
| **Offline Data** | Encrypted `assets/routes.bin` → `SharedPreferences` cache → `sqflite` SQLite with FTS5 full-text search on stops and routes |
| **Maps** | `flutter_map` + OpenStreetMap tiles (`latlong2`, `flutter_map_cancellable_location`) |
| **Location** | `geolocator` (GPS, streaming positions, geocoding) |
| **Notifications** | `flutter_local_notifications` (arrival + admin channels) |
| **Background Service** | `flutter_background_service` with dynamic polling interval (10s near stop → 60s far away) for battery optimization |
| **Vibration / TTS** | `vibration`, `flutter_tts` (Burmese `my-MM` locale) |
| **Device ID** | Random UUID per installation (SharedPreferences) |
| **NLP** | Myanmar Soundex phonetic matching for fuzzy Burmese stop-name resolution |
| **Web Support** | Conditional `dart:html` import for same-origin CORS workaround |

---

## Architecture

### App Shell & Navigation

```
main.dart
  → NotifyService.init()
  → BackgroundAlertService.initAndroid()
  → ChangeNotifierProvider<AppState>
      → YbsApp (MaterialApp, light-only theme, no debug banner)
          → RootShell (IndexedStack with 7 tabs)
              ├── HomePage       (tab 0)
              ├── AssistantPage  (tab 1)
              ├── YbsNewPage     (tab 2)
              ├── RoutesPage     (tab 3)
              ├── FindRoutePage  (tab 4)
              ├── FavoritesPage  (tab 5)
              ├── LeaderboardPage (tab 6)
```

No named routes or routing library; uses manual `Navigator.push` and `IndexedStack` for tab switching.

### Data Flow

```
App Boot
  → DataRepository.load()
      → Try SharedPreferences cache (instant)
      → Try assets/routes.bin (base64 → XOR obfuscation → gzip → JSON)
          → Populate BusRoute + BusStop models
          → Persist to SharedPreferences
          → Build SQLite database (routes.db) for fast JOIN queries
  → AppState.init() loads favorites, trips, leaderboard name
  → SplashScreen (bouncing bus animation) → RootShell
```

### Route Search (Offline-First, 2-Phase)

1. **SQLite direct-route JOIN** — Correct forward direction by township group + `stop_order`. Handles same-name stops across townships.
2. **In-memory BFS planner** — Max 2 transfers, sorts by transfer count then distance when no direct route exists.
3. **Local NLP** — `extractStopsFromText()` extracts start/end from Burmese text; `resolveStopName()` fuzzy-resolves via Levenshtein + Myanmar Soundex phonetic matching for dialect/variant names.
4. **Disambiguation** — Duplicate stop names get `"road · township"` suffix.

### Encrypted Route Bundle

Tools:
```
tools/routes_src/ → build_routes_bundle.dart → base64 + XOR + gzip → assets/routes.bin
```

Not production-grade encryption (key is in binary), but prevents casual APK extraction.

### Arrival Alert Flow

**In-app:** `NotifyService.triggerArrival()` → vibration + system notification + Burmese TTS

**Background (app closed/screen off):**
- `flutter_background_service` polls GPS + server with dynamic interval (10s near stop → 60s far away) for battery optimization
- Fires full-screen intent + vibration + TTS + screen wake lock
- Native `MainActivity.kt` wake-lock channel via `MethodChannel`

---

## Key Directories

```
lib/
├── main.dart              # Entry + RootShell navigation shell
├── config.dart            # AppConfig, AppColors, OSM tile URLs
├── models.dart            # Data models: BusStop, BusRoute, PathStep, SearchResult, etc.
├── theme.dart             # AppTheme + Material 3 light theme
├── data/
│   ├── data_repository.dart   # Bundle loading, caching, SQLite init
│   ├── route_finder.dart       # BFS planner, NLP, disambiguation, fuzzy + Soundex matching
│   ├── routes_crypto.dart     # XOR obfuscation key
│   └── sqlite_routes.dart     # SQLite JOIN queries for offline search
├── services/
│   ├── api_service.dart           # REST client (bus updates, predictions, feedback, leaderboard, rewards)
│   ├── background_alert_service.dart  # Foreground service for arrival alerts + admin polling
│   ├── device_service.dart        # Random UUID device ID via SharedPreferences
│   ├── local_store.dart           # SharedPreferences (favorites, trips, notifications)
│   ├── location_service.dart      # Geolocator wrapper
│   └── notify_service.dart        # Local notifications + Burmese TTS
├── state/
│   └── app_state.dart         # Global ChangeNotifier
├── pages/                     # 12 screens (home, assistant, routes, find-route, favorites, leaderboard, settings, route detail, route plan, stop detail, map picker, ybs new)
└── widgets/                   # Reusable widgets (bus updates feed, OSM map, modals, route badge)
```

---

## Backend

All API calls target **`https://ybs-mm-v2.vercel.app`**

Endpoints consumed:
- `/api/bus-updates` — CRUD for community bus updates
- `/api/bus?action=predictions` — Route stop predictions
- `/api/bus?action=eta` — Live bus ETA
- `/api/feedback` — User feedback submission
- `/api/notifications` — Admin push-style notifications (polled)
- `/api/leaderboard` — Register, submit update, rank, vote
- `/api/rewards` — List + redemption

No authentication layer; device ID serves as user identity.

---

## Build & Development

```bash
flutter pub get
flutter run
flutter build apk --release    # Android
flutter build ios --release    # iOS
```

> Note: Background alert service requires Android foreground service + boot receiver permissions configured in `android/app/src/main/AndroidManifest.xml`.
