# Changelog

All notable changes to the Flutter application are documented here.

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
