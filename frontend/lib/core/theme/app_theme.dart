import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// MMU Brand Colours — Mountains of the Moon University
class AppColors {
  // Primary palette (max 3 colours)
  static const mmwNavy  = Color(0xFF003087); // Primary — headers, buttons, active states
  static const mmwGreen = Color(0xFF00A651); // Secondary — badges, highlights, success
  static const mmwGold  = Color(0xFFF5A500); // Tertiary — scores, stats, accents

  // Derived shades
  static const navyDark   = Color(0xFF001A4D);
  static const navyLight  = Color(0xFF1A4FA0);
  static const greenDark  = Color(0xFF006B35);
  static const greenLight = Color(0xFF33C47A);
  static const goldDark   = Color(0xFFC47A00);

  // Neutrals
  static const background = Color(0xFFF0F4F8);
  static const surface    = Colors.white;
  static const cardBg     = Color(0xFFF8FAFC);
  static const textDark   = Color(0xFF0D1B2A);
  static const textMid    = Color(0xFF4A5568);
  static const textLight  = Color(0xFF718096);
  static const divider    = Color(0xFFE2E8F0);

  // Dark mode
  static const darkBg      = Color(0xFF0A111F);
  static const darkSurface = Color(0xFF0F1D30);
  static const darkCard    = Color(0xFF162031);
}

class AppTheme {
  // Legacy references maintained for backward-compat
  static const primaryColor   = AppColors.mmwNavy;
  static const secondaryColor = AppColors.mmwGreen;
  static const tertiaryColor  = AppColors.mmwGold;
  static const backgroundColor = AppColors.background;
  static const surfaceColor    = AppColors.surface;
  static const errorColor      = Color(0xFFD32F2F);

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.mmwNavy,
        primary: AppColors.mmwNavy,
        secondary: AppColors.mmwGreen,
        tertiary: AppColors.mmwGold,
        background: AppColors.background,
        surface: AppColors.surface,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onBackground: AppColors.textDark,
        onSurface: AppColors.textDark,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textDark,
        displayColor: AppColors.textDark,
        decorationColor: AppColors.textDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.mmwNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          letterSpacing: 0.3,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.mmwNavy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.3),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.mmwNavy,
          side: const BorderSide(color: AppColors.mmwNavy, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.mmwNavy),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F4F8),
        labelStyle: const TextStyle(color: AppColors.textMid, fontSize: 14),
        hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.8)),
        prefixIconColor: AppColors.textMid,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.mmwNavy, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 2,
        shadowColor: AppColors.mmwNavy.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.mmwNavy.withOpacity(0.08),
        labelStyle: const TextStyle(color: AppColors.mmwNavy, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith(
          (s) => s.contains(MaterialState.selected) ? AppColors.mmwGreen : Colors.white,
        ),
        trackColor: MaterialStateProperty.resolveWith(
          (s) => s.contains(MaterialState.selected) ? AppColors.mmwGreen.withOpacity(0.5) : AppColors.divider,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.mmwNavy,
        selectedItemColor: AppColors.mmwGold,
        unselectedItemColor: Colors.white70,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
        unselectedLabelStyle: TextStyle(fontSize: 10),
        elevation: 8,
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: AppColors.mmwNavy,
        primary: AppColors.navyLight,
        secondary: AppColors.mmwGreen,
        tertiary: AppColors.mmwGold,
        background: AppColors.darkBg,
        surface: AppColors.darkSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onBackground: Colors.white,
        onSurface: Colors.white,
      ),
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      scaffoldBackgroundColor: AppColors.darkBg,
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith(
          (s) => s.contains(MaterialState.selected) ? AppColors.mmwGreen : Colors.white54,
        ),
        trackColor: MaterialStateProperty.resolveWith(
          (s) => s.contains(MaterialState.selected) ? AppColors.mmwGreen.withOpacity(0.5) : Colors.white12,
        ),
      ),
    );
  }
}
