import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seedColor = Color(0xFFE8681B);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        centerTitle: false,
        // A leading icon gets 56 points to sit in, so its glyph lands 16 from
        // the left; actions run flush to the edge, so theirs land 12 from the
        // right. The 4 makes both 16, which is the inset the title, the
        // dividers and the floating bar all use.
        actionsPadding: const EdgeInsetsDirectional.only(end: 4),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(space: 1, thickness: 1),
    );
  }
}

/// Extra space a screen leaves on its right edge, on top of its own padding.
///
/// Zero on a phone, where 16 is the whole width budget. A desktop window is
/// wide and carries a 220-point sidebar on the left, which makes the same 16
/// read as cramped.
///
/// Taken from the theme rather than `dart:io` so an override reaches it and a
/// test can render either width, the same way `HomeScreen` picks its
/// navigation.
double rightGutter(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.macOS ? 8 : 0;

/// Padding that leaves an app bar's trailing action on the screen's right
/// edge, gutter included. The app bar's own background still runs full width.
EdgeInsetsGeometry appBarActionsPadding(BuildContext context) =>
    (AppBarTheme.of(context).actionsPadding ?? EdgeInsets.zero).add(
      EdgeInsetsDirectional.only(end: rightGutter(context)),
    );
