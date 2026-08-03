import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// A panel that refracts and blurs whatever passes behind it.
///
/// [borderRadius] is not decoration: it is the outline the refraction is solved
/// against and the path the backdrop is clipped to, so a panel given the wrong
/// radius bends light in the wrong place rather than merely looking wrong. The
/// shader takes one radius for the whole shape, which is why this is a `double`
/// and not a [BorderRadius].
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 0,
    this.border,
    this.blurSigma = 12,
    this.opacity = 0.5,
  });

  final Widget child;

  /// Radius of the squircle the glass is cut to.
  final double borderRadius;

  /// Drawn inside the glass, over the refraction. Null leaves the panel with
  /// only the specular edge the shader draws itself.
  final BoxBorder? border;

  /// Zero renders the panel with no [BackdropFilter] at all, which is what lets
  /// a header that is clear at rest cost nothing at rest.
  final double blurSigma;

  /// Alpha of the surface tint the glass carries. Lower than the frosted panel
  /// this replaced: the shader supplies a body of its own now, and an opaque
  /// tint would bury the refraction the panel exists to show.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AdaptiveGlass(
      shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
      // Standard rather than premium. Premium captures the backdrop into a
      // texture that is not scroll-position aware, and every glass panel in
      // this app sits over a list.
      quality: GlassQuality.standard,
      settings: LiquidGlassSettings(
        glassColor: colorScheme.surface.withValues(alpha: opacity),
        blur: blurSigma,
        thickness: 12,
        refractiveIndex: 1.2,
        // Chrome carries a hairline and no drop shadow, here as before.
        shadowElevation: 0,
      ),
      // Elevation is for controls that press; these are surfaces.
      allowElevation: false,
      child: border == null
          ? child
          : DecoratedBox(
              decoration: BoxDecoration(
                border: border,
                // The hairline has to follow the same corners the glass is cut
                // to, or it is stroked as a rectangle and the clip takes the
                // ends off it. Left null at zero because `Border` refuses a
                // radius unless every side is the same, and the panels that
                // carry one edge only are all square.
                borderRadius: borderRadius == 0
                    ? null
                    : BorderRadius.circular(borderRadius),
              ),
              child: child,
            ),
    );
  }
}

/// The hairline that separates the panel from what scrolls behind it. It does
/// that job alone: chrome carries no shadow, so this is the only thing lifting
/// the panel off the content.
///
/// Dark mode lights the edge; on a white canvas a white edge is invisible, so
/// light mode darkens it instead.
BorderSide glassEdge(BuildContext context) {
  final brightness = Theme.of(context).brightness;
  return BorderSide(
    color: brightness == Brightness.light
        ? Colors.black.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.15),
  );
}
