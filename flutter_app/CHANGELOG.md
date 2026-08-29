# Changelog

All notable changes to the Flutter application are documented here.

## 3.3.5 — 2026-08-27

### Fixed

- Reworked Home quick actions to open Route Search, Routes, and Assistant as independent pages instead of relying on IndexedStack tab switching.
- Removed the embedded OpenStreetMap view from Stop Detail so nearest-stop navigation no longer enters the shared map/plugin path that could force-close the app; map opening remains available through an external Google Maps action.
- Added range-safe root tab selection and Material-safe standalone page wrappers for more predictable navigation.
- Added widget regression coverage for all three Home quick actions.

### Improved

- Bumped the Android release to `3.3.5+10`.

## 3.3.4 — 2026-08-27

### Fixed

- Restored a visible, keyboard-safe Assistant chat composer with a multiline Burmese input, send button, loading state, and stable widget keys.
- Removed the redundant re-plan card, map-picker controls, and duplicate per-step arrival-alert toggles from Route Plan Detail; route planning remains available from the Find Route tab.
- Added regression coverage for the Assistant composer and kept the light-only theme behavior covered.

### Improved

- Bumped the Android release to `3.3.4+9`.

## 3.3.3 — 2026-08-27

### Fixed

- Added an explicit route-directory empty state and a search clear action.
- Replaced generic route-directory copy with the route's actual display name and Burmese labels.
- Hardened route-bundle parsing so malformed entries, coordinates, and empty routes do not crash startup.
- Added spacing-tolerant and fuzzy stop-name matching, plus safe search failure handling.
- Made background GPS alerts opt-in, disabled boot auto-start, stopped the foreground service when the alert queue ends, and removed full-screen notification behavior.

### Improved

- Added disabled-button contrast and consistent Material button sizing for the light theme.
- Added a privacy policy document and aligned the in-app privacy explanation with the current data flow.
- Bumped the Android release to `3.3.3+8`.

## 3.3.2 — 2026-08-27

### Fixed

- Removed the broken Light/Dark mode switch and the Display & Theme settings page.
- Restored the original light-mode palette as the single app theme so text and cards keep consistent contrast across screens.
- Removed dark-mode preference persistence from local storage and app state.

### Improved

- Bumped the Android release to `3.3.2+7` for the Play Store update.

## 3.3.1 — 2026-08-27

### Fixed

- Temporarily hid YBS New from the Play Store build without deleting its implementation; its page, home shortcut, and tab item can be restored through one feature flag.
- Fixed quick-action navigation indices when the temporary tab is hidden.
- Made notification and background-service startup best-effort so platform-specific initialization failures do not block app boot.

### Improved

- Aligned the in-app version with the release version (`3.3.1+6`).
- Added upload-keystore signing support, Play Store App Bundle output, tester APK output, release metadata hashes, and CI signing-secret validation.
- Removed the unused battery-optimization bypass permission and added a regression test for the temporary feature flag.

## 3.3.0 — 2026-08-22

### Improved

Route-detail maps now provide a clearer live-tracking workflow. Recent community bus reports remain visible as blue markers, the user’s GPS position is shown separately, and the tracking control follows the user while tracking is active. Tapping the active tracking control now recenters the map on the user instead of requesting location permission again. The bus control remains available for manually refreshing reported positions.

## 3.2.0 — 2026-08-22

### Added

The Settings screen now includes a persistent Display & Theme section. Users can switch between light and dark mode, and the choice is restored on the next launch.

### Improved

The dark theme uses a dedicated Material 3 color scheme, dark app bar, dark input surfaces, and accessible contrast while preserving the YBS amber brand accent. The in-app What's New panel now lists only implemented features and includes the cross-platform web route-loading fix.

## 3.1.3 — 2026-08-22

### Fixed

- Fixed the Flutter web blank-screen startup failure caused by using `dart:io` gzip decoding for the bundled route data.
- Added a cross-platform `archive` decoder for web, Android, iOS, and desktop.
- Added a recoverable startup error screen with a Burmese retry action when local route data cannot be loaded.

### Improved

- Refreshed the dependency lock file for the current stable Flutter toolchain.
- Added GitHub Actions validation for dependency installation, analysis, tests, and the Flutter web release build.
- Updated the Flutter README to match the actual six-tab application and implemented API surface.

## 3.1.2 — 2026-08-21

- Fixed Flutter web route loading and published the first web-compatible release tag.

## 3.1.1 — 2026-08-21

- Refreshed Flutter dependencies and verified analysis, tests, and web release builds.
