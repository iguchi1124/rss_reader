import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'glass_surface.dart';

/// How far the content travels under the header before the glass is at full
/// strength. Short on purpose: the header answers the first flick rather than
/// resolving over a screenful.
const double _rampDistance = 16;

const double _blurSigma = 20;
const double _tintOpacity = 0.55;

/// A [Scaffold] whose app bar is clear while the content sits below it and
/// glass once the content has run underneath.
///
/// The body extends behind the app bar, which is the whole point — a
/// translucent header with nothing passing behind it is a tinted rectangle, the
/// same trap `HomeScreen` avoids with `extendBody` for the tab bar. It also
/// means [Scaffold] hands the bar's height down to [body] as `MediaQuery` top
/// padding, and a scroll view in there has to spend it: what it is clearing is
/// chrome of ours, not a system inset, so nothing pads it automatically.
class GlassHeaderScaffold extends StatefulWidget {
  const GlassHeaderScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.bottom,
    this.floatingActionButton,
  });

  final Widget title;

  /// Built below the [Scaffold], which is what lets `MediaQuery.paddingOf`
  /// inside it report the header's height as top padding. A widget the caller
  /// built would close over a context above the [Scaffold] and see the bare
  /// system inset instead, so this takes a builder rather than a widget.
  final WidgetBuilder body;

  final List<Widget>? actions;

  /// Sits below the toolbar and inside the same pane of glass.
  final PreferredSizeWidget? bottom;

  final Widget? floatingActionButton;

  @override
  State<GlassHeaderScaffold> createState() => _GlassHeaderScaffoldState();
}

class _GlassHeaderScaffoldState extends State<GlassHeaderScaffold> {
  /// A notifier rather than `setState` so a scroll repaints the header alone
  /// and not the list running under it.
  final _progress = ValueNotifier<double>(0);

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  /// Depth zero is the scroll view filling the body. A popup menu or a dialog
  /// opened over it reports from further in and must not move the header.
  void _report(int depth, ScrollMetrics metrics) {
    if (depth == 0) {
      _progress.value = (metrics.pixels / _rampDistance).clamp(0.0, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final scaffold = Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Padding(
          padding: appBarTitlePadding(context),
          child: widget.title,
        ),
        actionsPadding: appBarActionsPadding(context),
        actions: widget.actions,
        bottom: widget.bottom,
        // The glass is the entire surface of the header. Material's own
        // scrolled-under tint would be a second and opaque answer to the same
        // event, sitting behind the first.
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        // An app bar reads the status bar icons off its own background, and a
        // transparent one measures as black: light mode would get white glyphs
        // on a white surface. The surface behind the glass is the one to ask.
        //
        // Spelled out rather than taken from `SystemUiOverlayStyle.dark`, which
        // also carries an opaque black system navigation bar that Android would
        // then paint behind the floating tab bar.
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: brightness,
          statusBarIconBrightness: brightness == Brightness.light
              ? Brightness.dark
              : Brightness.light,
        ),
        flexibleSpace: ValueListenableBuilder<double>(
          valueListenable: _progress,
          builder: (context, progress, _) => _HeaderGlass(progress: progress),
        ),
      ),
      body: Builder(builder: widget.body),
      floatingActionButton: widget.floatingActionButton,
    );

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _report(notification.depth, notification.metrics);
        return false;
      },
      // A body that swaps one scroll view for another — a list emptied by
      // "mark all as read", say — scrolls nothing and so reports nothing,
      // which would leave the header glass over content no longer under it.
      // The replacement announces its metrics on its first layout, and that is
      // the only signal that the old offset is gone.
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          _report(notification.depth, notification.metrics);
          return false;
        },
        child: scaffold,
      ),
    );
  }
}

class _HeaderGlass extends StatelessWidget {
  const _HeaderGlass({required this.progress});

  /// Zero while the content is clear of the header, one once it is fully under.
  final double progress;

  @override
  Widget build(BuildContext context) {
    // Nothing is behind the header yet, so there is nothing to refract. Leaving
    // the panel out entirely rather than rendering it at zero strength is what
    // keeps a screen at rest free of a backdrop filter.
    if (progress == 0) {
      return const SizedBox.expand();
    }

    final edge = glassEdge(context);

    return GlassSurface(
      blurSigma: _blurSigma * progress,
      opacity: _tintOpacity * progress,
      border: Border(
        bottom: edge.copyWith(
          color: edge.color.withValues(alpha: edge.color.a * progress),
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}
