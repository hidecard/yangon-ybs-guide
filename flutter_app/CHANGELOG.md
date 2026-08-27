# Changelog

All notable changes to the Flutter application are documented here.

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
