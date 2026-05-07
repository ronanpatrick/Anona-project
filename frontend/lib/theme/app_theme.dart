import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Brand Colours ─────────────────────────────────────────────────────────────
class AnonaColors {
  AnonaColors._();

  // Core palette ---------------------------------------------------------------
  static const Color backgroundLight = Color(0xFFF5F5F0); // warm off-white
  static const Color backgroundDark  = Color(0xFF000000); // true OLED black
  static const Color surfaceDark     = Color(0xFF121212); // very dark grey
  static const Color surfaceDark2    = Color(0xFF1C1C1E); // elevated surface
  static const Color textPrimary     = Color(0xFF1A1A2E); // deep charcoal
  static const Color textSecondary   = Color(0xFF6B7280); // muted grey

  // Accent – Money Green (Stocks)
  static const Color moneyGreen      = Color(0xFF00875A);
  static const Color moneyGreenLight = Color(0xFF00C170);
  static const Color moneyGreenGlow  = Color(0x3300C170);

  // Accent – Prime Time Navy (Sports)
  static const Color primeNavy       = Color(0xFF0D1B2A);
  static const Color primeNavyMid    = Color(0xFF1A2B44);
  static const Color primeNavyAccent = Color(0xFF3D7DC8);

  // Status pills
  static const Color gainGreen  = Color(0xFF23C16B);
  static const Color lossRed    = Color(0xFFEF4444);
  static const Color liveOrange = Color(0xFFFF6D00);
  static const Color silverText = Color(0xFFC8D1DB);
}

// ── App Theme ─────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData getLightTheme({double fontSizeFactor = 1.0}) {
    const cs = ColorScheme(
      brightness: Brightness.light,
      primary:         AnonaColors.moneyGreen,
      onPrimary:       Colors.white,
      secondary:       AnonaColors.primeNavy,
      onSecondary:     Colors.white,
      error:           Color(0xFFDC2626),
      onError:         Colors.white,
      surface:         AnonaColors.backgroundLight,
      onSurface:       AnonaColors.textPrimary,
      surfaceContainerHighest: Color(0xFFE8E8E3),
      onSurfaceVariant: AnonaColors.textSecondary,
      outline:          Color(0xFFD1D5DB),
      shadow:           Color(0x1A000000),
    );

    final textTheme = _buildTextTheme(Brightness.light, cs)
        .apply(fontSizeFactor: fontSizeFactor);

    return _buildTheme(cs, textTheme);
  }

  static ThemeData getDarkTheme({double fontSizeFactor = 1.0}) {
    const cs = ColorScheme(
      brightness: Brightness.dark,
      primary:         AnonaColors.moneyGreenLight,
      onPrimary:       AnonaColors.backgroundDark,
      secondary:       AnonaColors.primeNavyAccent,
      onSecondary:     Colors.white,
      error:           Color(0xFFF87171),
      onError:         AnonaColors.backgroundDark,
      surface:         AnonaColors.backgroundDark,
      onSurface:       Colors.white,
      surfaceContainerHighest: AnonaColors.surfaceDark2,
      onSurfaceVariant: AnonaColors.silverText,
      outline:          Color(0xFF2C2C2E),
      shadow:           Color(0x33000000),
    );

    final textTheme = _buildTextTheme(Brightness.dark, cs)
        .apply(fontSizeFactor: fontSizeFactor);

    return _buildTheme(cs, textTheme);
  }

  // ── Shared ThemeData builder ────────────────────────────────────────────────
  static ThemeData _buildTheme(ColorScheme cs, TextTheme textTheme) {
    final isDark = cs.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: cs.brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      textTheme: textTheme,

      // Cards – squircle shape, no harsh shadow
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? AnonaColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? AnonaColors.surfaceDark2 : const Color(0xFFE8E8E3),
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      // AppBar – clean, flush
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: cs.onSurface),
      ),

      // Buttons – rounded pill, flat
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          side: BorderSide(color: cs.outline),
          textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0),
        ),
      ),

      // Bottom nav
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AnonaColors.surfaceDark : Colors.white,
        indicatorColor: cs.primary.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.all(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),

      // Sliders
      sliderTheme: SliderThemeData(
        activeTrackColor: cs.primary,
        thumbColor: cs.primary,
        overlayColor: cs.primary.withOpacity(0.12),
        inactiveTrackColor: cs.outline,
      ),

      // Drawer
      drawerTheme: DrawerThemeData(
        backgroundColor: isDark ? AnonaColors.surfaceDark : Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomLeft: Radius.circular(24),
          ),
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AnonaColors.surfaceDark2 : AnonaColors.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      // Dividers
      dividerTheme: DividerThemeData(
        color: isDark ? AnonaColors.surfaceDark2 : const Color(0xFFE8E8E3),
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ── Typography ──────────────────────────────────────────────────────────────
  /// Inter for UI text, Merriweather for long-form reading.
  static TextTheme _buildTextTheme(Brightness brightness, ColorScheme cs) {
    final isLight = brightness == Brightness.light;
    final primaryColor   = isLight ? AnonaColors.textPrimary : Colors.white;
    final secondaryColor = isLight ? AnonaColors.textSecondary : AnonaColors.silverText;

    // Display / Headline → Inter (bold, tight tracking)
    final displayBase = GoogleFonts.inter(color: primaryColor);
    // Body / Reading → Merriweather (serif, generous line height)
    final readingBase = GoogleFonts.merriweather(color: primaryColor);
    // Label / UI chrome → Inter (semi-bold)
    final labelBase   = GoogleFonts.inter(color: primaryColor);

    return TextTheme(
      displayLarge: displayBase.copyWith(
        fontSize: 57, fontWeight: FontWeight.w800, letterSpacing: -1.5, height: 1.05,
      ),
      displayMedium: displayBase.copyWith(
        fontSize: 45, fontWeight: FontWeight.w800, letterSpacing: -1.0, height: 1.1,
      ),
      displaySmall: displayBase.copyWith(
        fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.12,
      ),
      headlineLarge: displayBase.copyWith(
        fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.15,
      ),
      headlineMedium: displayBase.copyWith(
        fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.2, height: 1.2,
      ),
      headlineSmall: displayBase.copyWith(
        fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.1, height: 1.25,
      ),
      titleLarge: displayBase.copyWith(
        fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.2, height: 1.3,
      ),
      titleMedium: displayBase.copyWith(
        fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.1, height: 1.35,
      ),
      titleSmall: displayBase.copyWith(
        fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.4,
      ),
      // Article body uses Merriweather for an editorial feel
      bodyLarge: readingBase.copyWith(
        fontSize: 17, fontWeight: FontWeight.w400, letterSpacing: 0.1, height: 1.7,
        color: primaryColor,
      ),
      bodyMedium: readingBase.copyWith(
        fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: 0.1, height: 1.65,
        color: primaryColor,
      ),
      bodySmall: readingBase.copyWith(
        fontSize: 13, fontWeight: FontWeight.w400, height: 1.55,
        color: secondaryColor,
      ),
      labelLarge: labelBase.copyWith(
        fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0,
      ),
      labelMedium: labelBase.copyWith(
        fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3,
        color: secondaryColor,
      ),
      labelSmall: labelBase.copyWith(
        fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.4,
        color: secondaryColor,
      ),
    );
  }
}
