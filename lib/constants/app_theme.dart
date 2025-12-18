/// Creating custom color palettes is part of creating a custom app. The idea is to create
/// your class of custom colors, in this case `CompanyColors` and then create a `ThemeData`
/// object with those colors you just defined.
///
/// Resource:
/// A good resource would be this website: http://mcg.mbitson.com/
/// You simply need to put in the colour you wish to use, and it will generate all shades
/// for you. Your primary colour will be the `500` value.
///
/// Colour Creation:
/// In order to create the custom colours you need to create a `Map<int, Color>` object
/// which will have all the shade values. `const Color(0xFF...)` will be how you create
/// the colours. The six character hex code is what follows. If you wanted the colour
/// #114488 or #D39090 as primary colours in your setting, then you would have
/// `const Color(0x114488)` and `const Color(0xD39090)`, respectively.
///
/// Usage:
/// In order to use this newly created setting or even the colours in it, you would just
/// `import` this file in your project, anywhere you needed it.
/// `import 'path/to/setting.dart';`
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemeData {
  static const _lightFillColor = Colors.black;
  static const _darkFillColor = Colors.white;

  static final Color _lightFocusColor = Colors.black.withValues(alpha: 0.12);
  static final Color _darkFocusColor = Colors.white.withValues(alpha: 0.12);

  static ThemeData lightThemeData =
      themeData(lightColorScheme, _lightFocusColor, isDark: false);
  static ThemeData darkThemeData =
      themeData(darkColorScheme, _darkFocusColor, isDark: true);

  static ThemeData themeData(ColorScheme colorScheme, Color focusColor,
      {required bool isDark}) {
    final baseTextTheme = _textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      // Enforce a single font family across all screens and widgets
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: baseTextTheme,
      primaryColor: colorScheme.primary,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        iconTheme: IconThemeData(color: colorScheme.primary, size: 24),
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: -0.5,
        ),
        toolbarHeight: 64,
        centerTitle: false,
      ),
      iconTheme: IconThemeData(color: colorScheme.onPrimary, size: 24),
      canvasColor: colorScheme.surface,
      scaffoldBackgroundColor: colorScheme.surface,
      highlightColor: Colors.transparent,
      focusColor: focusColor,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        labelStyle: baseTextTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface.withOpacity(.7),
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        hintStyle: baseTextTheme.bodyMedium?.copyWith(
          color: isDark
              ? Colors.white.withOpacity(.5)
              : Colors.black.withOpacity(.5),
          fontSize: 15,
        ),
        prefixIconColor: colorScheme.onSurface.withOpacity(.7),
        suffixIconColor: colorScheme.onSurface.withOpacity(.7),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 2,
          shadowColor: colorScheme.primary.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          textStyle: baseTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: colorScheme.primary.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          textStyle: baseTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: colorScheme.primary, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          textStyle: baseTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: _textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: isDark
            ? colorScheme.surface.withOpacity(.95)
            : Colors.white,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.1),
        indicatorColor: colorScheme.primary.withOpacity(.15),
        labelTextStyle: WidgetStateProperty.all(
          baseTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: const Color(0xFF2B78FF),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? const Color(0xFF2B78FF) : Colors.black54,
            size: 24,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(.08),
        surfaceTintColor: isDark ? null : colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color.alphaBlend(
          _lightFillColor.withValues(alpha: 0.95),
          _darkFillColor,
        ),
        contentTextStyle: baseTextTheme.titleMedium!.apply(color: _darkFillColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withOpacity(0.2),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static const ColorScheme lightColorScheme = ColorScheme(
    // App primary per wireframe: vibrant blue for buttons and accents
    primary: Color(0xFF2B78FF),
    primaryContainer: Color(0xFF1E5EE0),
    secondary: Color(0xFFEFF4FF),
    secondaryContainer: Color(0xFFF5F8FF),
    surface: Color(0xFFFAFBFB),
    error: _lightFillColor,
    onError: _lightFillColor,
    onPrimary: _lightFillColor,
    onSecondary: Color(0xFF0D295F),
    onSurface: Color(0xFF1F1F1F),
    brightness: Brightness.light,
  );

  static const ColorScheme darkColorScheme = ColorScheme(
    primary: Color(0xFF6EA4FF),
    primaryContainer: Color(0xFF2B78FF),
    secondary: Color(0xFF0F2249),
    secondaryContainer: Color(0xFF0B1A37),
    surface: Color(0xFF111418),
    error: _darkFillColor,
    onError: _darkFillColor,
    onPrimary: _darkFillColor,
    onSecondary: _darkFillColor,
    onSurface: _darkFillColor,
    brightness: Brightness.dark,
  );

  static const _regular = FontWeight.w400;
  static const _medium = FontWeight.w500;
  static const _semiBold = FontWeight.w600;
  static const _bold = FontWeight.w700;
  static const _extraBold = FontWeight.w800;

  static final TextTheme _textTheme = TextTheme(
    displayLarge: GoogleFonts.inter(fontWeight: _extraBold, fontSize: 32.0, letterSpacing: -1.0),
    displayMedium: GoogleFonts.inter(fontWeight: _extraBold, fontSize: 28.0, letterSpacing: -0.5),
    displaySmall: GoogleFonts.inter(fontWeight: _bold, fontSize: 24.0, letterSpacing: -0.5),
    headlineLarge: GoogleFonts.inter(fontWeight: _bold, fontSize: 22.0, letterSpacing: -0.5),
    headlineMedium: GoogleFonts.inter(fontWeight: _bold, fontSize: 20.0, letterSpacing: -0.3),
    headlineSmall: GoogleFonts.inter(fontWeight: _semiBold, fontSize: 18.0, letterSpacing: -0.2),
    titleLarge: GoogleFonts.inter(fontWeight: _bold, fontSize: 18.0, letterSpacing: -0.2),
    titleMedium: GoogleFonts.inter(fontWeight: _semiBold, fontSize: 16.0, letterSpacing: 0),
    titleSmall: GoogleFonts.inter(fontWeight: _semiBold, fontSize: 14.0, letterSpacing: 0.1),
    bodyLarge: GoogleFonts.inter(fontWeight: _regular, fontSize: 16.0, letterSpacing: 0.15),
    bodyMedium: GoogleFonts.inter(fontWeight: _regular, fontSize: 14.0, letterSpacing: 0.25),
    bodySmall: GoogleFonts.inter(fontWeight: _regular, fontSize: 12.0, letterSpacing: 0.4),
    labelLarge: GoogleFonts.inter(fontWeight: _semiBold, fontSize: 14.0, letterSpacing: 0.1),
    labelMedium: GoogleFonts.inter(fontWeight: _medium, fontSize: 12.0, letterSpacing: 0.5),
    labelSmall: GoogleFonts.inter(fontWeight: _medium, fontSize: 11.0, letterSpacing: 0.5),
  );
}
