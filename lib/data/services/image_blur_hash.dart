import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../utils/blur_hash.dart';

/// The width the image is decoded at before hashing. A blur hash keeps a dozen
/// cosine components, so anything larger is averaged away again at a cost of
/// four multiplications per pixel.
const _sampleWidth = 32;

/// The blur hash of the encoded image in [bytes], or null when `dart:ui` cannot
/// decode them — an icon served as ICO or SVG, or a 404 page under an image
/// URL, both of which reach here.
Future<String?> encodeImageBlurHash(Uint8List bytes) async {
  ui.Image? image;
  try {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: _sampleWidth,
    );
    image = (await codec.getNextFrame()).image;
    codec.dispose();

    final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (pixels == null) return null;

    return encodeBlurHash(
      pixels.buffer.asUint8List(),
      image.width,
      image.height,
    );
  } on Exception {
    return null;
  } finally {
    image?.dispose();
  }
}
