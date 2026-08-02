import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Carries the macOS title bar height from `MainFlutterWindow`.
///
/// `getHeight` asks for the height the window has now; `setHeight` arrives
/// unprompted when it changes. Only the macOS runner answers, which is why the
/// channel is optional: everywhere else there is no title bar to report.
@visibleForTesting
const titleBarChannel = OptionalMethodChannel('rss_reader/title_bar');

/// Reports the hidden macOS title bar as a system inset.
///
/// `MainFlutterWindow` runs the Flutter view the full height of the window so
/// the title bar stops painting a system-coloured band over the app's surface.
/// Nothing reports the space the traffic lights and the window drag region
/// still occupy, so it is added here and spent by [SafeArea] and [AppBar] the
/// way a notch would be.
///
/// The height comes from the window rather than a constant because it is not
/// one: entering full screen turns the title bar into an overlay that covers
/// nothing, and reserving the strip anyway would leave a dead band above the
/// sidebar and every app bar for as long as the window stayed there.
class TitleBarInset extends StatefulWidget {
  const TitleBarInset({super.key, required this.child});

  final Widget child;

  @override
  State<TitleBarInset> createState() => _TitleBarInsetState();
}

class _TitleBarInsetState extends State<TitleBarInset> {
  double _height = 0;

  @override
  void initState() {
    super.initState();
    titleBarChannel.setMethodCallHandler(_onCall);
    _readHeight();
  }

  @override
  void dispose() {
    titleBarChannel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _readHeight() async {
    _setHeight(await titleBarChannel.invokeMethod<double>('getHeight') ?? 0);
  }

  Future<void> _onCall(MethodCall call) async {
    if (call.method == 'setHeight') {
      _setHeight(call.arguments as double);
    }
  }

  void _setHeight(double height) {
    if (!mounted || height == _height) {
      return;
    }
    setState(() => _height = height);
  }

  @override
  Widget build(BuildContext context) {
    if (_height == 0) {
      return widget.child;
    }

    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(
        padding: mediaQuery.padding.copyWith(top: _height),
      ),
      child: widget.child,
    );
  }
}
