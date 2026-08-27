import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Web-only `dart:html` access, isolated so the import is never pulled into
// native builds (which would trip avoid_web_libraries_in_flutter).
import 'web_origin.dart' if (dart.library.io) 'web_origin_stub.dart';

/// Global app configuration and constants.
class AppConfig {
  /// Same backend the web app talks to (Vercel serverless + Turso).
  ///
  /// On the web, calling the deployed Vercel origin directly is blocked by
  /// CORS (the server does not send `Access-Control-Allow-Origin`). The
  /// repo's Vite dev server already proxies `/api` -> the deployed app with
  /// `changeOrigin: true`, so same-origin requests avoid CORS entirely.
  /// We therefore use the current page origin on the web (works for
  /// `localhost:3000`, the Vercel deploy, or any host serving the app),
  /// and the deployed origin everywhere else (native apps hit it directly).
  static String get apiBase {
    if (kIsWeb) {
      // window.location.origin is e.g. "http://localhost:3000".
      final origin = currentWebOrigin();
      if (origin != null && origin.isNotEmpty) return origin;
    }
    return 'https://ybs-mm-v2.vercel.app';
  }

  /// Keep the YBS New implementation in the tree so it can be restored later,
  /// but hide its entry points for the Play Store release for now.
  static const bool showYbsNew = false;

  /// Keep the user-facing version aligned with pubspec.yaml.
  static const String appVersion = '3.3.4';

  // Stable bottom-navigation indices for quick actions and deep links.
  static const int homeTab = 0;
  static const int assistantTab = 1;
  static const int ybsNewTab = 2;
  static const int routesTab = showYbsNew ? 3 : 2;
  static const int findRouteTab = showYbsNew ? 4 : 3;
  static const int favoritesTab = showYbsNew ? 5 : 4;

  static const double avgBusSpeedKmh = 15;

  /// OSM tile URL (same as web Leaflet).
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osmUserAgent = 'net.arkaryan.ybs_guide';
}

/// Color palette mirroring the web app's index.css.
class AppColors {
  static const Color bg = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  /// The web "brand" accent = amber-600 (#d97706).
  static const Color brand = Color(0xFFD97706);
  static const Color brandLight = Color(0xFFFEF3C7);
  static const Color brandHover = Color(0xFFB45309);

  /// Primary dark (slate-900).
  static const Color primary = Color(0xFF0F172A);

  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldDark = Color(0xFF047857);
  static const Color emeraldLight = Color(0xFFECFDF5);
  static const Color rose = Color(0xFFF43F5E);
  static const Color roseLight = Color(0xFFFFF1F2);
  static const Color amber = Color(0xFFD97706);
  static const Color amberLight = Color(0xFFFEF3C7);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueLight = Color(0xFFEFF6FF);
  static const Color violet = Color(0xFF7C3AED);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
}
