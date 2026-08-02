import 'package:flutter/material.dart';

/// Height of the macOS title bar, which the window draws over the content.
const double macOSTitleBarHeight = 28;

/// Reports the hidden macOS title bar as a system inset.
///
/// `MainFlutterWindow` runs the Flutter view the full height of the window so
/// the title bar stops painting a system-coloured band over the app's surface.
/// Nothing reports the space the traffic lights and the window drag region
/// still occupy, so it is added here and spent by [SafeArea] and [AppBar] the
/// way a notch would be.
class TitleBarInset extends StatelessWidget {
  const TitleBarInset({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform != TargetPlatform.macOS) {
      return child;
    }

    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(
        padding: mediaQuery.padding.copyWith(top: macOSTitleBarHeight),
      ),
      child: child,
    );
  }
}
