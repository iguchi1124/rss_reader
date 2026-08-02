import 'dart:ui';

import 'package:flutter/material.dart';

/// A translucent panel over blurred backdrop.
///
/// [borderRadius] is clipped, not just decorated: a [BackdropFilter] blurs
/// everything inside its nearest ancestor clip, so without one here the blur
/// would cover the whole screen.
///
/// Only the frosting of Apple's Liquid Glass is reachable this way. The
/// refraction at the edges would need a fragment shader through
/// `ImageFilter.shader`, and the specular highlight is stood in for by
/// [borderColor].
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.border,
    this.blurSigma = 16,
    this.opacity = 0.7,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final BoxBorder? border;
  final double blurSigma;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        // Clamp rather than decal: decal samples transparent outside the
        // bounds, which darkens the edges of the panel.
        filter: ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
          tileMode: TileMode.clamp,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: opacity),
            borderRadius: borderRadius,
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The hairline that reads as the lit edge of the panel.
BorderSide glassEdge(BuildContext context) {
  final brightness = Theme.of(context).brightness;
  return BorderSide(
    color: Colors.white.withValues(
      alpha: brightness == Brightness.light ? 0.8 : 0.25,
    ),
  );
}
