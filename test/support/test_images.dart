import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A PNG of [top] over [bottom], standing in for a publisher's mark.
///
/// Drawn rather than checked in because what the blur hash needs is real
/// encoded image bytes, and two colours are enough to tell an upside-down
/// decode from a right-way-up one.
Future<Uint8List> pngBytes({
  Color top = const Color(0xffffffff),
  Color bottom = const Color(0xff000000),
  int size = 64,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.toDouble(), size / 2),
    Paint()..color = top,
  );
  canvas.drawRect(
    Rect.fromLTWH(0, size / 2, size.toDouble(), size / 2),
    Paint()..color = bottom,
  );

  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}
