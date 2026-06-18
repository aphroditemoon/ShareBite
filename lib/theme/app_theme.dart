import 'package:flutter/material.dart';

class AppTheme {
  // ── Brand colours (shared light/dark) ────────────────────────────────────
  static const Color primary      = Color(0xFF4F9BFF);
  static const Color primaryLight = Color(0xFF8EDFFF);
  static const Color primaryDark  = Color(0xFF2F73F6);
  static const Color secondary    = Color(0xFF61C9FF);
  static const Color accent       = Color(0xFF6AE4D9);
  static const Color green        = Color(0xFF26C281);
  static const Color teal         = Color(0xFF36C5D8);

  // ── Light surfaces ────────────────────────────────────────────────────────
  static const Color bgLight      = Color(0xFFF4FAFF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight    = Color(0xFFFFFFFF);
  static const Color textPrimary  = Color(0xFF12304C);
  static const Color textSecondary= Color(0xFF6A85A0);
  static const Color divider      = Color(0xFFE0ECF8);

  // ── Dark surfaces ─────────────────────────────────────────────────────────
  static const Color bgDark       = Color(0xFF0D1B2A);   // deep navy
  static const Color surfaceDark  = Color(0xFF152438);   // card bg
  static const Color cardDark     = Color(0xFF1C3049);   // elevated card
  static const Color sheetDark    = Color(0xFF1A2E42);   // bottom sheet
  static const Color inputDark    = Color(0xFF1E3450);   // input fill
  static const Color textPrimaryDark   = Color(0xFFE8F4FF); // near-white
  static const Color textSecondaryDark = Color(0xFFE8F4FF); // white text in dark mode
  static const Color dividerDark  = Color(0xFF1E3450);

  // ── Context-aware helpers ─────────────────────────────────────────────────
  static bool isDark(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;

  static Color bg(BuildContext ctx)      => isDark(ctx) ? bgDark      : bgLight;
  static Color surface(BuildContext ctx) => isDark(ctx) ? surfaceDark  : surfaceLight;
  static Color card(BuildContext ctx)    => isDark(ctx) ? cardDark     : cardLight;
  static Color sheet(BuildContext ctx)   => isDark(ctx) ? sheetDark    : Colors.white;
  static Color inputFill(BuildContext ctx)=> isDark(ctx) ? inputDark   : const Color(0xFFEAF6FF);
  static Color inputFill2(BuildContext ctx)=> isDark(ctx) ? inputDark  : const Color(0xFFF0EFF8);
  static Color txtPrimary(BuildContext ctx) =>
      isDark(ctx) ? textPrimaryDark   : textPrimary;
  static Color txtSecondary(BuildContext ctx) =>
      isDark(ctx) ? textSecondaryDark : textSecondary;
  static Color div(BuildContext ctx) => isDark(ctx) ? dividerDark : divider;
  static Color statsBg(BuildContext ctx) =>
      isDark(ctx) ? primary.withOpacity(0.14) : primary.withOpacity(0.08);
  static Color tabBar(BuildContext ctx)  => isDark(ctx) ? surfaceDark  : Colors.white;
  static Color navBar(BuildContext ctx)  => isDark(ctx) ? bgDark       : Colors.white;
  static Color stickyHeader(BuildContext ctx) => isDark(ctx) ? bgDark  : bgLight;

  // ── Category colours ──────────────────────────────────────────────────────
  static const Map<String, Color> categoryColors = {
    'free_food'   : Color(0xFF31C7D7),
    'free_nonfood': Color(0xFF5D9DFF),
    'for_sale'    : Color(0xFF3D7BFF),
    'borrow'      : Color(0xFF5AD0FF),
    'wanted'      : Color(0xFF6F8DFF),
  };
  static const Map<String, String> categoryLabels = {
    'free_food'   : 'Free Food',
    'free_nonfood': 'Free Non-Food',
    'for_sale'    : 'For Sale',
    'borrow'      : 'Borrow',
    'wanted'      : 'Wanted',
  };
  static const Map<String, IconData> categoryIcons = {};

  // ── Gradients ─────────────────────────────────────────────────────────────
  static LinearGradient primaryGradient({
    Alignment begin = Alignment.topLeft,
    Alignment end   = Alignment.bottomRight,
  }) => LinearGradient(
    begin: begin, end: end,
    colors: const [Color(0xFF97EEFF), Color(0xFF62B8FF), Color(0xFF3D7BFF)],
    stops: const [0.0, 0.55, 1.0],
  );

  static LinearGradient skyGradient({
    Alignment begin = Alignment.topLeft,
    Alignment end   = Alignment.bottomRight,
  }) => LinearGradient(
    begin: begin, end: end,
    colors: const [Color(0xFFE8FBFF), Color(0xFFD6F3FF), Color(0xFFBFE7FF)],
  );

  // Dark equivalent of skyGradient — deep navy tones
  static LinearGradient skyGradientDark({
    Alignment begin = Alignment.topLeft,
    Alignment end   = Alignment.bottomRight,
  }) => LinearGradient(
    begin: begin, end: end,
    colors: const [Color(0xFF0D1B2A), Color(0xFF112030), Color(0xFF152438)],
  );

  /// Returns the correct sky gradient based on theme brightness
  static LinearGradient skyGradientFor(BuildContext ctx, {
    Alignment begin = Alignment.topLeft,
    Alignment end   = Alignment.bottomRight,
  }) => isDark(ctx)
      ? skyGradientDark(begin: begin, end: end)
      : skyGradient(begin: begin, end: end);

  static LinearGradient gradientFor(
    Color base, {
    Alignment begin = Alignment.topLeft,
    Alignment end   = Alignment.bottomRight,
  }) {
    final light = Color.lerp(base, Colors.white, 0.26)!;
    final dark  = Color.lerp(base, const Color(0xFF2E6FE8), 0.18)!;
    return LinearGradient(begin: begin, end: end, colors: [light, dark]);
  }

  static BoxDecoration gradientDecoration({
    BorderRadius? borderRadius,
    List<Color>? colors,
    Alignment begin = Alignment.topLeft,
    Alignment end   = Alignment.bottomRight,
    List<BoxShadow>? boxShadow,
  }) => BoxDecoration(
    gradient: LinearGradient(
      begin: begin, end: end,
      colors: colors ?? const [Color(0xFF97EEFF), Color(0xFF62B8FF), Color(0xFF3D7BFF)],
    ),
    borderRadius: borderRadius,
    boxShadow: boxShadow,
  );

  // ── Light theme ───────────────────────────────────────────────────────────
  static ThemeData lightTheme() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Nunito',
    colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.light).copyWith(
      primary: primary, secondary: secondary,
      surface: surfaceLight,
      onPrimary: Colors.white, onSecondary: Colors.white, onSurface: textPrimary,
    ),
    scaffoldBackgroundColor: bgLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white, foregroundColor: textPrimary,
      elevation: 0, centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'Nunito', fontSize: 20,
          fontWeight: FontWeight.w800, color: textPrimary),
    ),
    cardTheme: CardThemeData(
      color: cardLight, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary, foregroundColor: Colors.white,
        elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 16),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: const Color(0xFFEAF6FF),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: const TextStyle(fontFamily: 'Nunito', color: Color(0xFF9DB5CB), fontSize: 15),
    ),
    chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent),
  );

  // ── Dark theme ────────────────────────────────────────────────────────────
  static ThemeData darkTheme() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Nunito',
    colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.dark).copyWith(
      primary: primary, secondary: secondary,
      surface: surfaceDark,
      onPrimary: Colors.white, onSecondary: Colors.white, onSurface: textPrimaryDark,
    ),
    scaffoldBackgroundColor: bgDark,
    textTheme: ThemeData.dark().textTheme.apply(
      fontFamily: 'Nunito',
      bodyColor: textPrimaryDark,
      displayColor: textPrimaryDark,
    ),
    primaryTextTheme: ThemeData.dark().primaryTextTheme.apply(
      fontFamily: 'Nunito',
      bodyColor: textPrimaryDark,
      displayColor: textPrimaryDark,
    ),
    iconTheme: const IconThemeData(color: textPrimaryDark),
    listTileTheme: const ListTileThemeData(
      textColor: textPrimaryDark,
      iconColor: textPrimaryDark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surfaceDark, foregroundColor: textPrimaryDark,
      elevation: 0, centerTitle: false,
      titleTextStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 20,
          fontWeight: FontWeight.w800, color: textPrimaryDark),
    ),
    cardTheme: CardThemeData(
      color: cardDark, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary, foregroundColor: Colors.white,
        elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 16),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: inputDark,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: TextStyle(fontFamily: 'Nunito', color: textSecondaryDark.withOpacity(0.7), fontSize: 15),
    ),
    chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent),
    dividerTheme: const DividerThemeData(color: dividerDark),
    tabBarTheme: const TabBarThemeData(
      labelColor: primary,
      unselectedLabelColor: textSecondaryDark,
      indicatorColor: primary,
      dividerColor: dividerDark,
    ),
  );
}
