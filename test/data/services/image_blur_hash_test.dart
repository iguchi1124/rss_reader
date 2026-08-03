import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rss_reader/data/services/image_blur_hash.dart';
import 'package:rss_reader/utils/blur_hash.dart';

import '../../support/test_images.dart';

void main() {
  // Decoding an image goes through the engine.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hashes an image it can decode', () async {
    final hash = await encodeImageBlurHash(
      await pngBytes(
        top: const Color(0xffffffff),
        bottom: const Color(0xff000000),
      ),
    );

    expect(hash, isNotNull);

    // The halves survive as light over dark, so the image reached the encoder
    // the way round it was drawn.
    final pixels = decodeBlurHash(hash!, width: 4, height: 4)!;
    expect(pixels.first & 0xff, greaterThan(pixels.last & 0xff));
  });

  test('returns null for bytes that are not an image', () async {
    // What an icon URL answering with an error page reaches here as.
    final hash = await encodeImageBlurHash(
      Uint8List.fromList('<html>Not found</html>'.codeUnits),
    );

    expect(hash, isNull);
  });
}
