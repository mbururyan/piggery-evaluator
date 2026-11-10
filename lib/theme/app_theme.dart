import 'package:flutter/material.dart';

/// Piggery Evaluator palette: FCL red + white, light-first.
/// Same shape as Ranch Evaluator's AppColors, different tokens.
///
/// The one rule that matters: brand red is NEVER a status colour.
/// Problems are [alert] (burnt orange) and always carry a word on the pill,
/// so red on screen only ever means "FCL" or "the main action".
class AppColors {
  AppColors._();

  // ── Brand ────────────────────────────────────────────────────────────────
  // Placeholder until FCL supplies its exact brand hex. Swap this one line.
  static const red = Color(0xFFC8102E);
  static const redDark = Color(0xFF9E0B23); // hero gradient end, pill text
  static const redTint = Color(0xFFFCEBEE); // icon circles, role pill

  // ── Surfaces & text ──────────────────────────────────────────────────────
  static const white = Color(0xFFFFFFFF); // cards, inputs, nav bar
  static const page = Color(0xFFF7F5F2); // background behind cards
  static const ink = Color(0xFF1E1E1E); // primary text
  static const muted = Color(0xFF6B6B6B); // secondary text, idle icons
  static const line = Color(0xFFE4E0DB); // dividers
  // Input outlines are a step darker than [line]: EOs fill forms outdoors,
  // and a field edge that disappears in sunlight is a field they miss.
  static const inputBorder = Color(0xFFCFC9C2);

  // ── Status ───────────────────────────────────────────────────────────────
  static const green = Color(0xFF1F7A3D); // synced, okay, meets
  static const greenTint = Color(0xFFE6F2EA);

  static const amber = Color(0xFFD98A12); // pending sync, drafts, approaching
  static const amberTint = Color(0xFFFBF1E0);
  // Amber is too light to read as text on its own tint; use this instead.
  static const amberText = Color(0xFF8A560A);

  static const alert = Color(0xFFC2410C); // no, needs attention, below, errors
  static const alertTint = Color(0xFFFCEDE5);
}

/// Ranch Evaluator's dark surfaces separated cards from the page for free.
/// On a light page, white cards need a faint shadow to do the same job.
/// Borders would work too, but they're what made v1 look boxy.
class AppShadows {
  AppShadows._();

  static const card = [
    BoxShadow(color: Color(0x0F1E1E1E), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x0A1E1E1E), offset: Offset(0, 1), blurRadius: 1),
  ];
}

ThemeData buildAppTheme() {
  OutlineInputBorder border(Color color, [double width = 0.8]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );

  // Spelled out by hand instead of ColorScheme.fromSeed(): fromSeed would
  // shift our red to a "tonal" shade, and the brand red has to come out
  // exactly as specified.
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.red,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.redTint,
    onPrimaryContainer: AppColors.redDark,
    secondary: AppColors.ink,
    onSecondary: AppColors.white,
    // Form errors use burnt orange, not red: red is the brand, not a status.
    error: AppColors.alert,
    onError: AppColors.white,
    surface: AppColors.white,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    outline: AppColors.inputBorder,
    outlineVariant: AppColors.line,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.page,
    dividerColor: AppColors.line,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
      labelStyle: const TextStyle(color: AppColors.muted),
      errorStyle: const TextStyle(color: AppColors.alert, fontSize: 12),
      enabledBorder: border(AppColors.inputBorder),
      disabledBorder: border(AppColors.line),
      focusedBorder: border(AppColors.red, 1.5),
      errorBorder: border(AppColors.alert),
      focusedErrorBorder: border(AppColors.alert, 1.5),
      prefixIconColor: AppColors.muted,
      suffixIconColor: AppColors.muted,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.red),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppColors.red),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
    ),
  );
}