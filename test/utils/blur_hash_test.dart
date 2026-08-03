import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rss_reader/utils/blur_hash.dart';

/// [rows] is one colour per row, given as `0xRRGGBB` and repeated across the
/// width, so a caller can describe an image as a vertical gradient.
Uint8List image(List<int> rows, {int width = 8}) {
  final pixels = Uint8List(width * rows.length * 4);
  for (var y = 0; y < rows.length; y++) {
    for (var x = 0; x < width; x++) {
      final offset = (y * width + x) * 4;
      pixels[offset] = (rows[y] >> 16) & 0xff;
      pixels[offset + 1] = (rows[y] >> 8) & 0xff;
      pixels[offset + 2] = rows[y] & 0xff;
      pixels[offset + 3] = 0xff;
    }
  }
  return pixels;
}

int red(int pixel) => (pixel >> 16) & 0xff;
int green(int pixel) => (pixel >> 8) & 0xff;
int blue(int pixel) => pixel & 0xff;

void main() {
  group('encodeBlurHash', () {
    test('writes one character per component plus the header', () {
      final hash = encodeBlurHash(image(List.filled(8, 0x808080)), 8, 8);

      expect(hash, hasLength(4 + 2 * 4 * 3));
    });

    test('component counts survive the round trip', () {
      final hash = encodeBlurHash(
        image(List.filled(8, 0x808080)),
        8,
        8,
        componentsX: 6,
        componentsY: 2,
      );

      expect(hash, hasLength(4 + 2 * 6 * 2));
      expect(decodeBlurHash(hash, width: 4, height: 4), isNotNull);
    });
  });

  group('decodeBlurHash', () {
    test('restores a flat colour', () {
      final hash = encodeBlurHash(
        image(List.filled(32, 0x3366cc), width: 32),
        32,
        32,
      );

      final pixels = decodeBlurHash(hash, width: 4, height: 4)!;

      // Approximately, not exactly. The basis is sampled at each pixel's left
      // edge rather than its centre, so the components that should cancel over
      // a flat image do not quite, and the residue is a few percent of the
      // colour — most visible on the brightest channel. Every implementation
      // of the format shares this; sampling it wider only shrinks it.
      for (final pixel in pixels) {
        expect(red(pixel), closeTo(0x33, 20));
        expect(green(pixel), closeTo(0x66, 20));
        expect(blue(pixel), closeTo(0xcc, 20));
      }
    });

    test('keeps where the image was light and where it was dark', () {
      final hash = encodeBlurHash(
        image([...List.filled(4, 0xffffff), ...List.filled(4, 0x000000)]),
        8,
        8,
      );

      final pixels = decodeBlurHash(hash, width: 8, height: 8)!;

      expect(red(pixels.first), greaterThan(red(pixels.last)));
    });

    test('fills the size it is asked for', () {
      final hash = encodeBlurHash(image(List.filled(8, 0x808080)), 8, 8);

      expect(decodeBlurHash(hash, width: 3, height: 5), hasLength(15));
    });

    test('reads a hash written elsewhere', () {
      // From the reference implementation's README, so the size flag and the
      // alphabet are read the way every other implementation writes them.
      expect(
        decodeBlurHash('LEHV6nWB2yk8pyo0adR*.7kCMdnj', width: 4, height: 4),
        hasLength(16),
      );
    });

    test('returns null for a string that is not a hash', () {
      expect(decodeBlurHash('', width: 4, height: 4), isNull);
      expect(decodeBlurHash('not a hash', width: 4, height: 4), isNull);
      // The right shape, one character short of the length its size flag asks
      // for.
      expect(
        decodeBlurHash('LEHV6nWB2yk8pyo0adR*.7kCMdn', width: 4, height: 4),
        isNull,
      );
      // A character outside the base83 alphabet.
      expect(
        decodeBlurHash(r'LEHV6nWB2yk8pyo0adR*.7kCMdn\', width: 4, height: 4),
        isNull,
      );
    });
  });
}
