import 'package:flutter/material.dart';

class YBSDesignSystem {
  YBSDesignSystem._();

  // ---------------------------------------------------------------------------
  // LAYOUT — One-Handed Architecture
  // ---------------------------------------------------------------------------
  static const double oneHandedZoneFraction = 0.35;
  static const double minTouchTarget = 48.0;
  static const double dismissVelocity = 300.0;

  static EdgeInsets oneHandedSafeZone(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return EdgeInsets.only(bottom: height * oneHandedZoneFraction);
  }

  // ---------------------------------------------------------------------------
  // HIGH-CONTRAST DARK MODE
  // ---------------------------------------------------------------------------
  static const Color darkBg = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF0A0A0A);
  static const Color darkSurfaceRaised = Color(0xFF141414);
  static const Color darkBorder = Color(0xFF1E1E1E);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkTextMuted = Color(0xFFB3B3B3);

  // ---------------------------------------------------------------------------
  // TYPOGRAPHY
  // ---------------------------------------------------------------------------
  static const String fontFamily = 'NotoSansMyanmar';
  static const double textXS = 10.0;
  static const double textSM = 12.0;
  static const double textMD = 14.0;
  static const double textLG = 16.0;
  static const double textXL = 20.0;
  static const double text2XL = 24.0;
  static const double text3XL = 30.0;

  // ---------------------------------------------------------------------------
  // COLORS
  // ---------------------------------------------------------------------------
  static const Color brand = Color(0xFFD97706);
  static const Color brandHover = Color(0xFFB45309);
  static const Color brandLight = Color(0xFFFEF3C7);
  static const Color primary = Color(0xFF0F172A);
  static const Color primaryLight = Color(0xFF1E293B);
  static const Color accentViolet = Color(0xFF7C3AED);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentRose = Color(0xFFF43F5E);
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // ---------------------------------------------------------------------------
  // MOTION
  // ---------------------------------------------------------------------------
  static const Duration durationFade = Duration(milliseconds: 180);
  static const Duration durationSlide = Duration(milliseconds: 260);
  static const Duration durationScale = Duration(milliseconds: 200);
  static const Duration durationProgress = Duration(milliseconds: 400);
  static const Duration durationBounce = Duration(milliseconds: 350);
  static const Curve curveOut = Curves.easeOut;
  static const Curve curveInOut = Curves.easeInOut;
  static const Curve curveBounce = Curves.bounceOut;
}
