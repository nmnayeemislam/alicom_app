import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../state/theme_state.dart';

/// Alicom storefront palette — matches the home screen's bright, teal-accent
/// look in light mode; a dimmed variant of the same hues at night rather
/// than a different brand.
class _Dark {
  static const primary = Color(0xFF2CB5AC);
  static const primaryDark = Color(0xFF0A9A92);
  static const primaryLight = Color(0xFF6FD0C8);
  static const primarySoft = Color(0xFF12302E);
  static const ink = Color(0xFFF5F4F8);
  static const inkStrong = Color(0xFFFFFFFF);
  static const body = Color(0xFFAEACB8);
  static const bodyStrong = Color(0xFFC9C7D1);
  static const muted = Color(0xFF7C7A87);
  static const line = Color(0xFF2B2A33);
  static const lineStrong = Color(0xFF3E3C48);
  static const surface = Color(0xFF17161C);
  static const background = Color(0xFF0A0A0D);
  static const card = Color(0xFF141319);
  static const onAccent = Color(0xFF0A2624);
  static const sale = Color(0xFFEF6C86);
}

class _Light {
  static const primary = Color(0xFF0A9A92);
  static const primaryDark = Color(0xFF077E77);
  static const primaryLight = Color(0xFF4DBDB4);
  static const primarySoft = Color(0xFFE2F3F2);
  static const ink = Color(0xFF14142B);
  static const inkStrong = Color(0xFF0F0D16);
  static const body = Color(0xFF6E7191);
  static const bodyStrong = Color(0xFF433F52);
  static const muted = Color(0xFF8B8799);
  static const line = Color(0xFFEDEDF5);
  static const lineStrong = Color(0xFFD9D8E6);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF6F6FB);
  static const card = Color(0xFFFFFFFF);
  static const onAccent = Color(0xFFFFFFFF);
  static const sale = Color(0xFFE94560);
}

/// Reads [ThemeState.isDark] rather than `Theme.of(context)` since call
/// sites across the app use these as plain static values. See
/// [ThemeState] for how a mode switch propagates.
class AppColors {
  AppColors._();

  static bool get _dark => ThemeState.instance.isDark;

  /// Set once `/settings/branding` resolves, so an admin-configured accent
  /// overrides the default teal in both light and dark mode.
  static Color? _brandPrimary;
  static void setBrandPrimary(Color color) => _brandPrimary = color;

  static Color get primary => _brandPrimary ?? (_dark ? _Dark.primary : _Light.primary);
  static Color get primaryDark => _dark ? _Dark.primaryDark : _Light.primaryDark;
  static Color get primaryLight => _dark ? _Dark.primaryLight : _Light.primaryLight;
  static Color get primarySoft => _dark ? _Dark.primarySoft : _Light.primarySoft;

  static Color get leaf => primary;
  static Color get leafSoft => primarySoft;

  static Color get accent => primary;
  static Color get accentDark => primaryDark;
  static Color get accentLight => primaryLight;
  static Color get accentSoft => primarySoft;

  static Color get ink => _dark ? _Dark.ink : _Light.ink;
  static Color get inkStrong => _dark ? _Dark.inkStrong : _Light.inkStrong;
  static Color get body => _dark ? _Dark.body : _Light.body;
  static Color get bodyStrong => _dark ? _Dark.bodyStrong : _Light.bodyStrong;
  static Color get muted => _dark ? _Dark.muted : _Light.muted;
  static Color get line => _dark ? _Dark.line : _Light.line;
  static Color get lineStrong => _dark ? _Dark.lineStrong : _Light.lineStrong;
  static Color get surface => _dark ? _Dark.surface : _Light.surface;

  static Color get background => _dark ? _Dark.background : _Light.background;
  static Color get card => _dark ? _Dark.card : _Light.card;
  static Color get onAccent => _dark ? _Dark.onAccent : _Light.onAccent;

  /// Price/discount emphasis red — matches the home screen's sale pricing.
  static Color get sale => _dark ? _Dark.sale : _Light.sale;
}

class AppTheme {
  AppTheme._();

  /// Status/navigation bar colours for the active palette: light icons on
  /// the near-black dark surfaces, dark icons on the off-white light ones.
  /// Applied on every theme change and again when the splash (which uses
  /// its own dark bars) hands over to the app.
  static SystemUiOverlayStyle systemOverlayStyle(bool isDark) => SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark ? const Color(0xFF0A0A0D) : const Color(0xFFF7F6FB),
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      );


  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final palette = isDark ? _Dark.card : _Light.card;
    final background = isDark ? _Dark.background : _Light.background;
    final line = isDark ? _Dark.line : _Light.line;
    final ink = isDark ? _Dark.ink : _Light.ink;
    final inkStrong = isDark ? _Dark.inkStrong : _Light.inkStrong;
    final body = isDark ? _Dark.body : _Light.body;
    final muted = isDark ? _Dark.muted : _Light.muted;
    final primary = isDark ? _Dark.primary : _Light.primary;
    final primaryLight = isDark ? _Dark.primaryLight : _Light.primaryLight;
    final onAccent = isDark ? _Dark.onAccent : _Light.onAccent;
    final lineStrong = isDark ? _Dark.lineStrong : _Light.lineStrong;

    final headingFont = GoogleFonts.interTightTextTheme();
    final bodyFont = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        secondary: primary,
        surface: background,
      ),
      textTheme: bodyFont.copyWith(
        titleLarge: headingFont.titleLarge?.copyWith(color: inkStrong, fontWeight: FontWeight.w700),
        titleMedium: headingFont.titleMedium?.copyWith(color: inkStrong, fontWeight: FontWeight.w600),
        titleSmall: headingFont.titleSmall?.copyWith(color: inkStrong, fontWeight: FontWeight.w600),
        bodyLarge: bodyFont.bodyLarge?.copyWith(color: ink),
        bodyMedium: bodyFont.bodyMedium?.copyWith(color: body),
        bodySmall: bodyFont.bodySmall?.copyWith(color: muted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: inkStrong,
        elevation: 0,
        surfaceTintColor: background,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: palette,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette,
        hintStyle: TextStyle(color: muted),
        labelStyle: TextStyle(color: body),
        prefixIconColor: muted,
        suffixIconColor: muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE94560)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE94560), width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onAccent,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15.5),
          shadowColor: primary.withValues(alpha: 0.4),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: inkStrong,
          side: BorderSide(color: line),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryLight),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(onAccent),
        side: BorderSide(color: lineStrong),
      ),
      dividerColor: line,
      iconTheme: IconThemeData(color: ink),
      fontFamily: GoogleFonts.inter().fontFamily,
    );
  }
}
