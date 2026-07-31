import 'package:flutter/material.dart';
import 'design_system.dart';
import '../config.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      colorScheme: ColorScheme.fromSeed(
        seedColor: YBSDesignSystem.brand,
        primary: AppColors.primary,
        secondary: AppColors.brand,
        surface: AppColors.surface,
        surfaceContainerHighest: AppColors.slate100,
      ),
      fontFamily: YBSDesignSystem.fontFamily,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: YBSDesignSystem.brand, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: YBSDesignSystem.brandLight,
        selectedColor: YBSDesignSystem.brandHover,
        labelStyle: const TextStyle(color: AppColors.text),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: YBSDesignSystem.brand,
        unselectedItemColor: AppColors.slate400,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final cs = const ColorScheme.dark(
      surface: YBSDesignSystem.darkSurface,
      surfaceContainerHighest: YBSDesignSystem.darkSurfaceRaised,
      onSurface: YBSDesignSystem.darkText,
      primary: YBSDesignSystem.brand,
      onPrimary: Colors.white,
      secondary: YBSDesignSystem.accentViolet,
      onSecondary: Colors.white,
      outline: YBSDesignSystem.darkBorder,
      error: YBSDesignSystem.danger,
      onError: Colors.white,
      brightness: Brightness.dark,
    );

    return ThemeData.from(
      colorScheme: cs,
      useMaterial3: true,
    ).copyWith(
      textTheme: Typography.material2021().black.apply(
            fontFamily: YBSDesignSystem.fontFamily,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: YBSDesignSystem.darkSurface,
        foregroundColor: YBSDesignSystem.darkText,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: YBSDesignSystem.darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(
            color: YBSDesignSystem.darkTextMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: YBSDesignSystem.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: YBSDesignSystem.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: YBSDesignSystem.brand, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: YBSDesignSystem.darkSurfaceRaised,
        selectedColor: YBSDesignSystem.brandLight,
        labelStyle: const TextStyle(color: YBSDesignSystem.darkText),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: YBSDesignSystem.darkSurface,
        selectedItemColor: YBSDesignSystem.brand,
        unselectedItemColor: YBSDesignSystem.darkTextMuted,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: YBSDesignSystem.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      cardTheme: CardThemeData(
        color: YBSDesignSystem.darkSurfaceRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: YBSDesignSystem.darkBorder, width: 0.5),
        ),
      ),
      dividerColor: YBSDesignSystem.darkBorder,
    );
  }
}

/// Common decorations reused across pages.
class UI {
  UI._();

  static BoxDecoration card({Color? color, Color? border}) => BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: border ?? AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      );

  static BoxDecoration cardDark({Color? border}) => BoxDecoration(
        color: YBSDesignSystem.darkSurfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border ?? YBSDesignSystem.darkBorder),
      );

  static const sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  static const sectionTitleDark = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: YBSDesignSystem.darkText,
  );

  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    letterSpacing: 0.2,
  );

  static const labelDark = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: YBSDesignSystem.darkTextMuted,
    letterSpacing: 0.2,
  );
}
