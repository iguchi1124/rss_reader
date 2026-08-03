import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../utils/blur_hash.dart';

/// The blurred image a blur hash stands for, filling whatever space it is
/// given.
///
/// A hash that does not decode paints nothing, so a caller with something
/// better to show than an empty box should not reach here with one.
class BlurHashView extends StatefulWidget {
  const BlurHashView({required this.hash, super.key});

  final String hash;

  @override
  State<BlurHashView> createState() => _BlurHashViewState();
}

class _BlurHashViewState extends State<BlurHashView> {
  /// Both axes of the grid the hash is decoded into. A blur hash carries a
  /// dozen cosine components, so this is already well past the point where more
  /// samples add detail; what it buys is squares small enough to read as a
  /// gradient at the sizes this is drawn at.
  static const _resolution = 32;

  late Uint32List? _pixels = _decode();

  Uint32List? _decode() =>
      decodeBlurHash(widget.hash, width: _resolution, height: _resolution);

  @override
  void didUpdateWidget(BlurHashView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hash != oldWidget.hash) _pixels = _decode();
  }

  @override
  Widget build(BuildContext context) {
    final pixels = _pixels;
    if (pixels == null) return const SizedBox.expand();

    return CustomPaint(
      size: Size.infinite,
      painter: _BlurHashPainter(pixels: pixels, resolution: _resolution),
    );
  }
}

class _BlurHashPainter extends CustomPainter {
  const _BlurHashPainter({required this.pixels, required this.resolution});

  final Uint32List pixels;
  final int resolution;

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / resolution;
    final cellHeight = size.height / resolution;
    // Cells are drawn a hair over their share so antialiasing along the shared
    // edge cannot leave the background showing through as a grid.
    const overdraw = 0.5;
    final paint = Paint();

    for (var y = 0; y < resolution; y++) {
      for (var x = 0; x < resolution; x++) {
        paint.color = Color(pixels[y * resolution + x]);
        canvas.drawRect(
          Rect.fromLTWH(
            x * cellWidth,
            y * cellHeight,
            cellWidth + overdraw,
            cellHeight + overdraw,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BlurHashPainter oldDelegate) =>
      oldDelegate.pixels != pixels;
}
