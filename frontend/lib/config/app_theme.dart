import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet warna utama:
/// - Charcoal: background utama & teks
/// - Emerald Green: aksen & bubble user
/// - Sage Green: bubble AI & elemen sekunder
abstract final class AppColors {
  // ─── Emerald Green (aksen utama) ──────────────────────────────
  static const Color primary = Color(0xFF10B981);         // emerald-500
  static const Color primaryLight = Color(0xFF34D399);    // emerald-400
  static const Color primaryDark = Color(0xFF059669);     // emerald-600

  // ─── Charcoal (background utama) ─────────────────────────────
  static const Color backgroundLight = Color(0xFFF6F8F7);
  static const Color backgroundDark = Color(0xFF1A1A2E);  // charcoal deep
  static const Color surfaceDark = Color(0xFF16213E);      // charcoal surface

  // ─── Text ─────────────────────────────────────────────────────
  static const Color textDark = Color(0xFF0F172A);
  static const Color textLight = Color(0xFFF1F5F9);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textMutedDark = Color(0xFF94A3B8);

  // ─── Border ───────────────────────────────────────────────────
  static const Color borderDark = Color(0xFF334155);
  static const Color borderLight = Color(0xFFCBD5E1);

  // ─── Chat-specific ────────────────────────────────────────────
  static const Color chatBg = Color(0xFF1A1A2E);           // charcoal
  static const Color bubbleAi = Color(0xFF2D4A3E);         // sage green gelap
  static const Color bubbleUser = Color(0xFF065F46);       // emerald-800
  static const Color inputSurface = Color(0xFF1E2D4A);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);

  // ─── Sage Green (secondaries) ─────────────────────────────────
  static const Color sageLight = Color(0xFF87AE9E);
  static const Color sageMuted = Color(0xFF5C8A75);

  // ─── Drawer ───────────────────────────────────────────────────
  static const Color drawerSurface = Color(0xFF16213E);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color scrollThumb = Color(0xFF2D4A3E);
}

// konfigurasi tema aplikasi untuk mode terang dan gelap
abstract final class AppTheme {
  // tema gelap
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: AppColors.surfaceDark,
        onPrimary: AppColors.backgroundDark,
        onSurface: AppColors.textLight,
      ),
      textTheme: _buildTextTheme(base.textTheme, Colors.white),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.backgroundDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 56),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textMutedDark,
          side: const BorderSide(color: AppColors.borderDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 56),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // tema terang
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSurface: AppColors.textDark,
      ),
      textTheme: _buildTextTheme(base.textTheme, AppColors.textDark),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 56),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textMuted,
          side: const BorderSide(color: AppColors.borderLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 56),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.textDark,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // text theme yang dipakai bersama oleh kedua mode tema
  static TextTheme _buildTextTheme(TextTheme base, Color defaultColor) {
    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: defaultColor,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: defaultColor,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: defaultColor,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: defaultColor,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: defaultColor,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: defaultColor,
      ),
    );
  }
}
