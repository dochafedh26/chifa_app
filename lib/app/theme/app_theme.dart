import 'dart:io';

import 'package:flutter/material.dart';

/// Chifa Clinic — Premium Medical Theme
/// Uses a sophisticated teal + slate palette with the bundled
/// Bricolage Grotesque font for a modern, clinical aesthetic.
class AppTheme {
  AppTheme._();

  // ─── Platform-specific font scaling ─────────────────────────────────
  static double get _fontScale {
    if (Platform.isLinux) {
      return 1.3; // Increase font size on Linux by 15%
    }
    return 1.0; // Default scale for other platforms
  }

  static double get fontScale => _fontScale;

  // ─── Brand Palette ────────────────────────────────────────────────
  static const Color _primary = Color(0xFF0D9488); // teal-600
  static const Color _primaryLight = Color(0xFF14B8A6); // teal-500
  static const Color _primaryDark = Color(0xFF0F766E); // teal-700
  static const Color _secondary = Color(0xFF6366F1); // indigo-500
  static const Color _secondaryDark = Color(0xFF4F46E5); // indigo-600

  // Surfaces
  static const Color _bgLight = Color(0xFFF8FAFC); // slate-50
  static const Color _surfaceLight = Color(0xFFFFFFFF);
  static const Color _surfaceVariant = Color(0xFFF1F5F9); // slate-100
  static const Color _dividerColor = Color(0xFFE2E8F0); // slate-200

  // Text
  static const Color _textPrimary = Color(0xFF0F172A); // slate-900
  static const Color _textSecondary = Color(0xFF475569); // slate-600
  static const Color _textTertiary = Color(0xFF94A3B8); // slate-400

  // Sidebar
  static const Color _sidebarBg = Color(0xFF0F172A); // slate-900
  static const Color _sidebarSurface = Color(0xFF1E293B); // slate-800
  static const Color _sidebarText = Color(0xFFCBD5E1); // slate-300
  static const Color _sidebarTextActive = Color(0xFFFFFFFF);

  // Status
  static const Color _success = Color(0xFF22C55E);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _error = Color(0xFFEF4444);
  static const Color _info = Color(0xFF3B82F6);

  // ─── Font Family ──────────────────────────────────────────────────
  static const String _fontFamily = 'Bricolage-Grotesque';

  // ─── Getters for sidebar colours (used by MainShell) ──────────────
  static Color get sidebarBackground => _sidebarBg;
  static Color get sidebarSurface => _sidebarSurface;
  static Color get sidebarText => _sidebarText;
  static Color get sidebarTextActive => _sidebarTextActive;
  static Color get primary => _primary;
  static Color get primaryLight => _primaryLight;
  static Color get secondary => _secondary;
  static Color get textTertiary => _textTertiary;
  static Color get divider => _dividerColor;
  static Color get surfaceVariant => _surfaceVariant;
  static Color get bgLight => _bgLight;
  static Color get textSecondary => _textSecondary;

  // ─── Light Theme ──────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primary,
      primary: _primary,
      secondary: _secondary,
      surface: _surfaceLight,
      error: _error,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _bgLight,
      dividerColor: _dividerColor,

      // ── AppBar ──────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: _surfaceLight,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _textPrimary,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 18 * _fontScale,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
          letterSpacing: -0.3,
        ),
      ),

      // ── Cards ───────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _dividerColor, width: 1),
        ),
        color: _surfaceLight,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),

      // ── Dialogs ─────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        elevation: 8,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        surfaceTintColor: Colors.transparent,
        backgroundColor: _surfaceLight,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20 * _fontScale,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
        ),
      ),

      // ── Elevated Buttons ────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: Platform.isLinux ? 20 : (24 * _fontScale),
            vertical: Platform.isLinux ? 10 : (14 * _fontScale),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14 * _fontScale,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // ── Outlined Buttons ────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          side: const BorderSide(color: _dividerColor, width: 1.5),
          padding: EdgeInsets.symmetric(
            horizontal: Platform.isLinux ? 20 : (24 * _fontScale),
            vertical: Platform.isLinux ? 10 : (14 * _fontScale),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14 * _fontScale,
          ),
        ),
      ),

      // ── Text Buttons ────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          padding: EdgeInsets.symmetric(
            horizontal: Platform.isLinux ? 12 : (16 * _fontScale),
            vertical: Platform.isLinux ? 8 : (10 * _fontScale),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14 * _fontScale,
          ),
        ),
      ),

      // ── Floating Action Button ──────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),

      // ── Input Fields ────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceVariant,
        contentPadding: EdgeInsets.symmetric(
          horizontal: Platform.isLinux ? 14 : (16 * _fontScale),
          vertical: Platform.isLinux ? 10 : (14 * _fontScale),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error),
        ),
        labelStyle: TextStyle(
          fontFamily: _fontFamily,
          color: _textSecondary,
          fontWeight: FontWeight.w500,
          fontSize: 14 * _fontScale,
        ),
        hintStyle: TextStyle(
          fontFamily: _fontFamily,
          color: _textTertiary,
          fontSize: 14 * _fontScale,
        ),
      ),

      // ── Chips ───────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceVariant,
        selectedColor: _primary,
        labelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 13 * _fontScale,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        padding: EdgeInsets.symmetric(
          horizontal: Platform.isLinux ? 10 : (12 * _fontScale),
          vertical: Platform.isLinux ? 6 : (8 * _fontScale),
        ),
      ),

      // ── DataTable ───────────────────────────────────────────────
      dataTableTheme: DataTableThemeData(
        headingTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 13 * _fontScale,
          color: _textSecondary,
          letterSpacing: 0.5,
        ),
        dataTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14 * _fontScale,
          color: _textPrimary,
        ),
        headingRowColor: WidgetStateProperty.all(_surfaceVariant),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _dividerColor),
        ),
      ),

      // ── Divider ─────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: _dividerColor,
        thickness: 1,
        space: 1,
      ),

      // ── Snackbar ────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _sidebarBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: TextStyle(
          fontFamily: _fontFamily,
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 14 * _fontScale,
        ),
      ),

      // ── Tooltips ────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: _sidebarBg,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          fontFamily: _fontFamily,
          color: Colors.white,
          fontSize: 12 * _fontScale,
          fontWeight: FontWeight.w500,
        ),
        waitDuration: const Duration(milliseconds: 400),
      ),

      // ── NavigationRail (fallback; sidebar is custom) ────────────
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _sidebarBg,
        selectedIconTheme: IconThemeData(
          color: _sidebarTextActive,
          size: 22 * _fontScale,
        ),
        unselectedIconTheme: IconThemeData(
          color: _sidebarText.withValues(alpha: 0.7),
          size: 20 * _fontScale,
        ),
        selectedLabelTextStyle: TextStyle(
          fontFamily: _fontFamily,
          color: _sidebarTextActive,
          fontWeight: FontWeight.w700,
          fontSize: 11 * _fontScale,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: _fontFamily,
          color: _sidebarText.withValues(alpha: 0.7),
          fontWeight: FontWeight.w500,
          fontSize: 10 * _fontScale,
        ),
        indicatorColor: _primary.withValues(alpha: 0.2),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ── Tab Bar ─────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: _primary,
        unselectedLabelColor: _textTertiary,
        indicatorColor: _primary,
        labelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 13 * _fontScale,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w500,
          fontSize: 13 * _fontScale,
        ),
      ),

      // ── Icon Theme ──────────────────────────────────────────────
      iconTheme: IconThemeData(color: _textSecondary, size: 22 * _fontScale),
      primaryIconTheme: IconThemeData(color: _primary),

      // ── Text Theme ──────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w800,
          color: _textPrimary,
          letterSpacing: -1.5,
          fontSize: 57 * _fontScale,
        ),
        displayMedium: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
          letterSpacing: -1.0,
          fontSize: 45 * _fontScale,
        ),
        displaySmall: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
          letterSpacing: -0.5,
          fontSize: 36 * _fontScale,
        ),
        headlineLarge: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
          letterSpacing: -0.5,
          fontSize: 32 * _fontScale,
        ),
        headlineMedium: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
          letterSpacing: -0.3,
          fontSize: 28 * _fontScale,
        ),
        headlineSmall: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
          color: _textPrimary,
          fontSize: 24 * _fontScale,
        ),
        titleLarge: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
          color: _textPrimary,
          letterSpacing: -0.2,
          fontSize: 22 * _fontScale,
        ),
        titleMedium: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
          color: _textPrimary,
          fontSize: 16 * _fontScale,
        ),
        titleSmall: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
          color: _textSecondary,
          fontSize: 14 * _fontScale,
        ),
        bodyLarge: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w400,
          color: _textPrimary,
          height: 1.5,
          fontSize: 16 * _fontScale,
        ),
        bodyMedium: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w400,
          color: _textSecondary,
          height: 1.5,
          fontSize: 14 * _fontScale,
        ),
        bodySmall: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w400,
          color: _textTertiary,
          height: 1.4,
          fontSize: 12 * _fontScale,
        ),
        labelLarge: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
          color: _textPrimary,
          letterSpacing: 0.1,
          fontSize: 14 * _fontScale,
        ),
        labelMedium: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w500,
          color: _textSecondary,
          letterSpacing: 0.1,
          fontSize: 12 * _fontScale,
        ),
        labelSmall: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w500,
          color: _textTertiary,
          letterSpacing: 0.3,
          fontSize: 11 * _fontScale,
        ),
      ),
    );
  }
}
