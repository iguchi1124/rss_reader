import 'package:flutter/material.dart';

abstract final class AppTheme {
  /// Action Blue. Every interactive element takes it — links, pill CTAs, the
  /// unread marker, the focus signal — and there is deliberately no second
  /// accent. `secondaryContainer` is a tint of this rather than its own hue.
  static const _actionBlue = Color(0xFF0066CC);

  /// Action Blue disappears against a near-black tile, so dark mode swaps in
  /// the brighter Sky Link Blue and darkens the text that sits on it.
  static const _skyLinkBlue = Color(0xFF2997FF);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = _colorScheme(brightness);

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      textTheme: _textTheme,
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
      // A utility card: hairline instead of a shadow, since elevation is
      // reserved for imagery.
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      // The one input in the app is shaped like the search field: a capsule,
      // matching the CTA grammar rather than sitting in a rounded rectangle.
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      // The default FAB is a tonal container; adding a feed is the primary
      // action on its screen, so it takes the filled action colour.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          side: WidgetStatePropertyAll(
            BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
      ),
    );
  }

  static ColorScheme _colorScheme(Brightness brightness) {
    // Seeded so the roles nothing here pins still relate to the accent; every
    // role the design names is then given its own value.
    final base = ColorScheme.fromSeed(
      seedColor: _actionBlue,
      brightness: brightness,
    );

    return switch (brightness) {
      Brightness.light => base.copyWith(
        primary: _actionBlue,
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: const Color(0xFFE8F1FC),
        onPrimaryContainer: _actionBlue,
        secondary: const Color(0xFF333333),
        onSecondary: const Color(0xFFFFFFFF),
        secondaryContainer: const Color(0xFFE8F1FC),
        onSecondaryContainer: _actionBlue,
        surface: const Color(0xFFFFFFFF),
        onSurface: const Color(0xFF1D1D1F),
        surfaceContainerLowest: const Color(0xFFFFFFFF),
        surfaceContainerLow: const Color(0xFFF5F5F7),
        surfaceContainer: const Color(0xFFF5F5F7),
        surfaceContainerHigh: const Color(0xFFFFFFFF),
        surfaceContainerHighest: const Color(0xFFF5F5F7),
        onSurfaceVariant: const Color(0xFF333333),
        outline: const Color(0xFF7A7A7A),
        outlineVariant: const Color(0xFFE0E0E0),
        error: const Color(0xFFD70015),
        onError: const Color(0xFFFFFFFF),
        errorContainer: const Color(0xFFFDECEC),
        onErrorContainer: const Color(0xFFD70015),
        inverseSurface: const Color(0xFF1D1D1F),
        onInverseSurface: const Color(0xFFFFFFFF),
        surfaceTint: _actionBlue,
        scrim: const Color(0xFF000000),
      ),
      Brightness.dark => base.copyWith(
        primary: _skyLinkBlue,
        onPrimary: const Color(0xFF1D1D1F),
        primaryContainer: const Color(0xFF0A2A47),
        onPrimaryContainer: const Color(0xFF7FC0FF),
        secondary: const Color(0xFFCCCCCC),
        onSecondary: const Color(0xFF1D1D1F),
        secondaryContainer: const Color(0xFF0A2A47),
        onSecondaryContainer: _skyLinkBlue,
        surface: const Color(0xFF1D1D1F),
        onSurface: const Color(0xFFFFFFFF),
        surfaceContainerLowest: const Color(0xFF000000),
        surfaceContainerLow: const Color(0xFF252527),
        surfaceContainer: const Color(0xFF272729),
        surfaceContainerHigh: const Color(0xFF2A2A2C),
        surfaceContainerHighest: const Color(0xFF2F2F31),
        onSurfaceVariant: const Color(0xFFCCCCCC),
        outline: const Color(0xFF98989D),
        outlineVariant: const Color(0xFF38383A),
        error: const Color(0xFFFF6961),
        onError: const Color(0xFF1D1D1F),
        errorContainer: const Color(0xFF3A1513),
        onErrorContainer: const Color(0xFFFF6961),
        inverseSurface: const Color(0xFFF5F5F7),
        onInverseSurface: const Color(0xFF1D1D1F),
        surfaceTint: _skyLinkBlue,
        scrim: const Color(0xFF000000),
      ),
    };
  }

  /// Body copy runs at 17 rather than 16, and everything from 14 up carries a
  /// slight negative tracking — together they are what make the type read as
  /// Apple's. The weight ladder is 400 / 600 only: 500 is absent by design and
  /// headlines stop at 600 rather than reaching for 700.
  static const _textTheme = TextTheme(
    headlineSmall: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
      height: 1.14,
    ),
    titleLarge: TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.19,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.374,
      height: 1.24,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.224,
      height: 1.29,
    ),
    bodyLarge: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.374,
      height: 1.44,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.224,
      height: 1.43,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.12,
      height: 1.43,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.224,
      height: 1.43,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.12,
      height: 1.43,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.08,
      height: 1.3,
    ),
  );
}

/// Extra space a screen leaves on either edge, on top of its own padding.
///
/// Zero on a phone, where 16 is the whole width budget. A desktop window is
/// wide and carries a 220-point sidebar on the left, which makes the same 16
/// read as cramped against it and against the window's own edge.
///
/// Taken from the theme rather than `dart:io` so an override reaches it and a
/// test can render either width, the same way `HomeScreen` picks its
/// navigation.
double contentGutter(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.macOS ? 16 : 0;

/// Padding that leaves an app bar's trailing action on the screen's right
/// edge, gutter included. The app bar's own background still runs full width.
EdgeInsetsGeometry appBarActionsPadding(BuildContext context) =>
    (AppBarTheme.of(context).actionsPadding ?? EdgeInsets.zero).add(
      EdgeInsetsDirectional.only(end: contentGutter(context)),
    );

/// Padding that puts an app bar's title on the same left edge as the content
/// below it.
///
/// `AppBar` has no `titlePadding`, and its `titleSpacing` is also the gap after
/// a leading icon, so raising that would push the title away from a back button
/// as well as off the edge. The gutter goes around the title widget instead.
EdgeInsetsGeometry appBarTitlePadding(BuildContext context) =>
    EdgeInsetsDirectional.only(start: contentGutter(context));
