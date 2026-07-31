# YBS Guide (Yangon Bus Service)

Offline-first Flutter app for navigating Yangon's bus network with Burmese-language AI assistance, community updates, and live arrival alerts.

---

## 📱 App Overview

YBS AI is a full-featured Yangon bus navigation app with **7 main tabs**, 5+ detail screens, and a comprehensive settings panel. It works **offline-first** — all routes and stops are bundled in-app and cached locally.

---

## ✨ Features

### 🗺️ Navigation & Route Planning
- **Find Route** — Enter start/end stops (Burmese or English) with autocomplete and disambiguation; supports map picker and "Near Me" GPS
- **AI Assistant** — Burmese NLP chat interface ("A ကနေ B ကို") that extracts stops, fuzzy-resolves names, and runs BFS routing
- **Route Browsing** — Full list of YBS routes, searchable by route number, operator, or township; stop-by-stop details with OSM map
- **Offline BFS Routing** — 2-transfer max routing with shortest-forward-span ranking; works fully offline after first launch
- **Trip Re-planning** — Adjust route plans mid-journey from any step (swap start/end, use "Near Me", or pick from map)

### 📍 Live Tracking & Alerts
- **Arrival Alerts** — In-app vibration + Burmese TTS notification when bus nears selected stop
- **Background Alerts** — Foreground service polls GPS + server while app is closed; fires full-screen intent, wakes screen, speaks arrival in Burmese
- **ETA & Predictions** — Live ETA and prediction data from backend (polled every 15s)
- **Live GPS Tracking** — Real-time position tracking on route map with auto-stop detection and trip progress bar
- **iOS Live Activities** — Dynamic Island / Lock Screen live tracking for iOS 16.1+

### 💬 Community Features
- **YBS New Feed** — Real-time community bus updates (started, reached, road closed, delays, etc.)
- **Voting** — Upvote/downvote community updates with per-user vote tracking
- **Post Update** — Share live bus status via bottom sheet with type, stop, and notes
- **Report from Route** — Quick-report updates directly from any route detail page

### ⭐ Favorites & Personalization
- **Saved Trips** — Bookmark multi-step route plans for quick access
- **Favorite Stops & Routes** — Star frequently used stops and routes; sorted to top in lists
- **Commute Prediction Cards** — Morning/evening commute suggestions on home page (office/school routing, home-bound routing)
- **Travel Tips** — Quick tips for Yangon bus travel displayed on home screen
- **Recent Searches** — History of recent route lookups with delete and re-search
- **Leaderboard & Rewards** — Community ranking by contribution points, badge milestones (3 tiers), reward redemption (requires device ID)
- **Badge System** — Automatic badge progression: 🌱 YBS Starter (0 pts) → 🗺️ YBS Guide (200 pts) → 👑 YBS Legend (1000 pts)

### ⚙️ Settings & Utilities
- **Data Sync** — Refresh route bundle from assets and rebuild SQLite cache
- **Notification Setup** — 4-step guided setup for background alert service, battery optimization, autostart, and background data
- **TTS Troubleshooting** — Check and test Burmese text-to-speech availability; open Google TTS Play Store link for language pack download
- **Dark Mode** — High-contrast dark theme with dedicated color palette (true black background)
- **QR Payment Info** — Route cards show QR payment support badge where available
- **Privacy & Feedback** — Privacy policy, feedback dialog (bug/wrong info/suggestion/other), donation (KPay/Wave Money)
- **Admin Notifications** — In-app notification loading from backend on home page; forwarded to system notification tray
- **About / What's New** — App info, team details, version changelog

---

## 🧭 Usage Guide — Pages Overview

The app uses a **7-tab navigation shell** (`IndexedStack`). Below is how to use each screen.

### 🏠 Home Page (Tab 0)

The landing screen with personalized content:

- **Quick Actions Grid** — 4 shortcut cards:
  - "လမ်းကြောင်း ရှာရန်" (Find Route) → Tab 4
  - "ကားလိုင်းများ" (Bus Routes) → Tab 3
  - "YBS New" → Tab 2
  - "Assistant" → Tab 1
- **Commute Prediction Cards** — Shows automatically during morning (6–10 AM) and evening (4–8 PM) commute hours with office/school or home-bound route suggestions. Tapping opens Find Route.
- **Nearest Stops Card** — Tap "ယခု နေရာ" (Near Me) to show 5 closest stops with distance, route badges, and direct navigation to stop detail.
- **Travel Tips** — 4 helpful Yangon bus travel tips (weather prep, security, stop alerts, YBS card advice).
- **Recent Searches** — Last 10 trip history items with type indicators (search, route, stop). Tap to re-search, swipe to delete, "ဖယ်ရှားမည်" to clear all.

### 🤖 AI Assistant (Tab 1)

Burmese-language chat interface for route queries:

- **Chat Bubble UI** — User messages (right-aligned, brand color) / Assistant replies (left-aligned, white card).
- **Quick Query Chips** — Auto-generated "မြေနီကုန်းကနေ ဆူးလေကို" style suggestions based on available stops.
- **How to use**: Type in Burmese like "မြေနီကုန်းကနေ ဆူးလေကို ဘယ်လိုသွားရမလဲ" or "နောက်ဆုံး ဈေးကို" (nearest stop from my location).
- **Response**: Shows number of direct + transfer routes found, each with route badges and tap-to-view details.
- **NLP Features**: Extracts start/end stops, fuzzy-resolves misspelled names via Myanmar Soundex, supports "near me" queries via GPS.

### 📢 YBS New (Tab 2)

Community real-time bus update feed:

- **Feed Display**: Scrollable list of updates from other users showing route badge, type chip (started/reached/road closed/not running/other), stop name, notes, and timestamp.
- **Voting**: Upvote/downvote each update (per-user tracking, aggregated score shown).
- **Post Update**: Tap FAB "အချက်အလက် မျှဝေမည်" → Bottom sheet with:
  1. Select route from dropdown
  2. Choose update type (colored chips)
  3. Optional stop name and notes
  4. Submit → auto-earns leaderboard points
- **Route Quick-Report**: From Route Detail page, tap campaign icon → report directly for that route.

### 🚌 Routes (Tab 3)

Browse and search all YBS routes:

- **Search bar**: Filter by route number, operator name, start/end stop, or township (both Burmese and English).
- **Route cards**: Show route badge with color, operator name, start/end stops, stop count, star button for favorites. Sorted: favorites first, then by numeric route ID.
- **Tap card** → opens Route Detail page.

**Route Detail Page** (pushed on tap):
- **OSM Map** with stop markers (green=start, red=end, white=intermediate), route polyline, and live bus positions (blue dots).
- **FAB Controls**: 
  - 📍 Start/stop live GPS tracking (auto-detects current stop)
  - 🔔 Toggle arrival alerts (vibration + TTS at stops)
  - 🚌 Refresh live bus positions
- **Info Sections**: Total stops, predictions box (ETAs per stop), bus ETA box (green), journey progress bar (when tracking).
- **Stop List**: Numbered stops with road/township info. Active stop shows "လက်ရှိ" badge. Tap any stop → Stop Detail page.
- **Report Update**: AppBar campaign icon → quick-report dialog for this route.

### 🔍 Find Route (Tab 4)

Point-to-point route planner:

- **Start/End Fields**: Autocomplete with fuzzy Myanmar Soundex matching, "road · township" disambiguation for duplicate names.
- **Near Me**: GPS button to set start stop to nearest stop automatically.
- **Map Picker**: Map icon opens full-screen OSM map picker with crosshair — shows stops within 1km of map center, tap to select.
- **Swap Button**: Swap start/end stops with one tap.
- **Search Results**: Cards showing route badges, transfer count pill (direct / 1ဆင့်ပြောင်း / 2ဆင့်ပြောင်း), step-by-step breakdown with boarding/alighting labels and distance per leg.
- **Tap result** → opens Route Plan Detail page.

**Route Plan Detail Page** (pushed on tap):
- **Map** showing the planned route with leg markers (green=board, amber=transfer, red=alight).
- **Step Cards**: Active step highlighted with brand border. Shows route badge, transfer labels, boarding/alighting stops with road/township.
- **Intermediate Stops**: List of stops between board and alight.
- **Live GPS**: Auto-tracks position, highlights active step. Shows "Live GPS Active" badge.
- **Arrival Alerts**: Toggle per-step with "ရောက်ခါနီး သတိပေးချက်" button.
- **Save Trip**: Bookmark icon in AppBar to save the plan (appears under Favorites).
- **Re-planning**: Adjust start/end from within page using Near Me or map picker.

### ⭐ Favorites (Tab 5)

All saved content in one place:

- **Saved Trips**: Bookmarked multi-step route plans with route badges and start→end labels. Tap to view plan. Delete button to remove.
- **Favorite Stops**: Starred stops showing name, township, and unfavorite star button. Tap → Stop Detail page.
- **Favorite Routes**: Starred routes sorted to top of Routes tab. Tap → Route Detail page.
- **Empty State**: Helpful message when no favorites exist yet.

### 🏆 Leaderboard (Tab 6)

Community ranking and rewards system:

- **3 Tabs**: Profile | Leaderboard | Rewards

**Profile Tab:**
- Current badge display (🌱 YBS Starter / 🗺️ YBS Guide / 👑 YBS Legend) with icon, title, and subtitle
- Points and rank stats card
- Next badge progress bar (e.g. "100/200 pts to next badge")
- All badge levels listed with lock/unlock status and check mark for earned

**Leaderboard Tab:**
- My Rank card (amber gradient) with rank, username, points
- All Time / Monthly scope toggle (SegmentedButton)
- Top 100 ranked list with gold/silver/bronze styling for top 3
- Pull-to-refresh support

**Rewards Tab:**
- Current points banner
- Reward cards with icon, title, description, cost, stock count
- "ဆုလဲမည်" (Redeem) button — disabled if insufficient points or out of stock
- 2-step redeem: confirm dialog → phone/Telegram contact input → API call

**First-time setup**: Name registration dialog on first open.

### ⚙️ Settings (AppBar icon → pushed page)

10 menu items:

1. **Application Data** — Sync routes from assets, shows local cache size, "Update" button with progress states.
2. **Community & Leaderboard Guide** — Profile, badge, leaderboard, and rewards usage instructions in Burmese.
3. **အကြောင်းကြားချက် ဆက်တင်** — 4-step notification setup guide (battery optimization, notification permissions, autostart, background data) + "Setting ကိုဖွင့်မည်" button.
4. **အသံထွက်စနစ် ပြင်ဆင်ရန်** — TTS check (my-MM availability), "အသံစမ်းရန်" test button, "ပြင်ဆင်ရန် သွားမည်" (open Google TTS Play Store).
5. **အဖွဲ့အစည်း နှင့် စည်းကမ်းချက်များ** — Team info (founder, design, contact, links) and 6 terms of service.
6. **ဆော့ဝဲအကြောင်း** — About: app name, version, platform, developer contact, social links.
7. **ကိုယ်ရေးအချက်အလက် မူဝါဒ** — Privacy policy with 6 points on data handling.
8. **What's New in V3.1** — Changelog with 9 features (AI assistant, advanced routing, live location, offline maps, stop-to-stop navigation, smart notifications, shared trip, bus updates, dark mode).
9. **အကြံပြုချက် / အမှားတွက်** — Feedback dialog: type selection (bug/wrong info/suggestion/other), optional route ID, message field.
10. **Support This Project** — Donation card with KPay (09446941632) and Wave Money (09758430371) numbers + copy button.

### 🔧 Additional Detail Pages

- **Stop Detail Page**: OSM map with stop marker, township/road info box, list of passing routes (deduplicated by base line number), favorite toggle, tap route → Route Detail.
- **Map Picker Page**: Full-screen OSM map with center crosshair, "Near Me" FAB, bottom panel lists stops within 1km sorted by distance, tap to select.

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
| **Background Service** | `flutter_background_service` with speed-based dynamic polling interval for battery optimization |
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
- `flutter_background_service` polls GPS + server with dynamic interval based on proximity and vehicle speed for battery optimization
- Fires full-screen intent + vibration + TTS + screen wake lock
- Native `MainActivity.kt` wake-lock channel via `MethodChannel`
- Foreground notification displays live remaining distance to destination

---

## Recent Changes & Improvements

### Background Alert Service — Speed-Based Dynamic Polling
- Polling interval now considers both **proximity** and **vehicle speed**
- When speed is below 2 m/s (stationary / traffic jam) and within close range (< 0.5 km), polling backs off to 30s to preserve battery
- Foreground notification updates live with remaining distance to destination (km)
- Burmese TTS speech rate tuned to 0.85 for clearer pronunciation; alert text optimized for user comprehension

### Settings — System Links
- "Setting ကိုဖွင့်မည်" button now opens the app's system settings page using the `package:` URI scheme with `app-settings:` fallback
- Android manifest updated with `<queries>` for `package:`, `market:`, and `http(s)` schemes so external intents resolve correctly on Android 11+

### TTS Troubleshooting
- System TTS settings button opens Google TTS Play Store page directly (intent URI replaced with reliable Play Store link)
- Ensures users can download/install Burmese language pack even when the system TTS settings intent cannot be resolved

### YBS New Page
- `DropdownButtonFormField` uses the correct `initialValue` API for route selection
- Const-correctness fixed in widget trees to avoid compile errors from mixing const parents with dynamic children
- Post-update sheet preserves existing AppState architecture (`state.routes`, `state.repo.routeById`)

### Feedback
- Backend endpoint verified: `POST /api/feedback` returns `200 OK` with `{"ok":true}`
- Feedback dialog posts `type`, `message`, and optional `routeId` to the server

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

All API calls target **`https://ybs-ai.arkaryan.net`**

Endpoints consumed:
- `/api/bus-updates` — CRUD for community bus updates
- `/api/bus?action=predictions` — Route stop predictions
- `/api/bus?action=eta` — Live bus ETA
- `/api/feedback` — User feedback submission
- `/api/notifications` — Admin push-style notifications (polled)
- `/api/leaderboard` — Register, submit update, rank, vote
- `/api/rewards` — List + redemption
- `/api/routes/delta` — Incremental route data updates

No authentication layer; device ID serves as user identity.

---

## Build & Development

```bash
flutter pub get
flutter run
flutter build apk --debug    # Android debug
flutter build apk --release  # Android release
flutter build ios --release  # iOS
```

> Note: Background alert service requires Android foreground service + boot receiver permissions configured in `android/app/src/main/AndroidManifest.xml`.
