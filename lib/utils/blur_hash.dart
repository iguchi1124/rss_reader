import 'dart:math' as math;
import 'dart:typed_data';

/// BlurHash (https://blurha.sh): a handful of ASCII characters describing an
/// image as low-frequency cosine components, decodable into a blurred stand-in
/// for it.
///
/// Encoding and decoding are both here because the app does both — a feed's
/// icon is hashed once when it is downloaded and decoded on every list that
/// draws it before the image itself arrives.

const _digits =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#\$%*+,-.:;=?@[]^_{|}~';

/// Encodes [pixels], which must be row-major RGBA bytes of [width] x [height].
///
/// [componentsX] and [componentsY] are how many cosine components each axis
/// keeps, 1 to 9. More components means a longer string and a sharper blur.
String encodeBlurHash(
  Uint8List pixels,
  int width,
  int height, {
  int componentsX = 4,
  int componentsY = 3,
}) {
  assert(componentsX >= 1 && componentsX <= 9);
  assert(componentsY >= 1 && componentsY <= 9);
  assert(pixels.length >= width * height * 4);

  final factors = <_Rgb>[];
  for (var y = 0; y < componentsY; y++) {
    for (var x = 0; x < componentsX; x++) {
      factors.add(_basisFactor(pixels, width, height, x, y));
    }
  }

  final buffer = StringBuffer();
  buffer.write(_encode83((componentsX - 1) + (componentsY - 1) * 9, 1));

  final ac = factors.skip(1).toList();
  final double maximumValue;
  if (ac.isEmpty) {
    maximumValue = 1;
    buffer.write(_encode83(0, 1));
  } else {
    final actualMax = ac
        .map((factor) => [factor.r, factor.g, factor.b].map((v) => v.abs()))
        .expand((values) => values)
        .reduce(math.max);
    final quantisedMax = ((actualMax * 166 - 0.5).floor()).clamp(0, 82);
    maximumValue = (quantisedMax + 1) / 166;
    buffer.write(_encode83(quantisedMax, 1));
  }

  buffer.write(_encode83(_encodeDc(factors.first), 4));
  for (final factor in ac) {
    buffer.write(_encode83(_encodeAc(factor, maximumValue), 2));
  }

  return buffer.toString();
}

/// Decodes [hash] into [width] x [height] packed `0xAARRGGBB` pixels, or null
/// when the string is not a blur hash.
///
/// The size asked for is free: a hash carries no resolution of its own, and
/// anything above a few dozen pixels only interpolates what is already there.
Uint32List? decodeBlurHash(
  String hash, {
  required int width,
  required int height,
}) {
  if (hash.length < 6) return null;

  final sizeFlag = _decode83(hash.substring(0, 1));
  if (sizeFlag == null) return null;
  final componentsX = sizeFlag % 9 + 1;
  final componentsY = sizeFlag ~/ 9 + 1;
  if (hash.length != 4 + 2 * componentsX * componentsY) return null;

  final quantisedMax = _decode83(hash.substring(1, 2));
  final dc = _decode83(hash.substring(2, 6));
  if (quantisedMax == null || dc == null) return null;
  final maximumValue = (quantisedMax + 1) / 166;

  final colors = <_Rgb>[_decodeDc(dc)];
  for (var i = 1; i < componentsX * componentsY; i++) {
    final value = _decode83(hash.substring(4 + i * 2, 6 + i * 2));
    if (value == null) return null;
    colors.add(_decodeAc(value, maximumValue));
  }

  final pixels = Uint32List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var r = 0.0;
      var g = 0.0;
      var b = 0.0;
      for (var j = 0; j < componentsY; j++) {
        for (var i = 0; i < componentsX; i++) {
          final basis =
              math.cos(math.pi * x * i / width) *
              math.cos(math.pi * y * j / height);
          final color = colors[j * componentsX + i];
          r += color.r * basis;
          g += color.g * basis;
          b += color.b * basis;
        }
      }
      pixels[y * width + x] =
          0xff000000 |
          (_linearToSrgb(r) << 16) |
          (_linearToSrgb(g) << 8) |
          _linearToSrgb(b);
    }
  }
  return pixels;
}

typedef _Rgb = ({double r, double g, double b});

_Rgb _basisFactor(
  Uint8List pixels,
  int width,
  int height,
  int componentX,
  int componentY,
) {
  final normalisation = componentX == 0 && componentY == 0 ? 1.0 : 2.0;
  var r = 0.0;
  var g = 0.0;
  var b = 0.0;

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final basis =
          normalisation *
          math.cos(math.pi * componentX * x / width) *
          math.cos(math.pi * componentY * y / height);
      final offset = (y * width + x) * 4;
      r += basis * _srgbToLinear(pixels[offset]);
      g += basis * _srgbToLinear(pixels[offset + 1]);
      b += basis * _srgbToLinear(pixels[offset + 2]);
    }
  }

  final scale = 1 / (width * height);
  return (r: r * scale, g: g * scale, b: b * scale);
}

int _encodeDc(_Rgb color) =>
    (_linearToSrgb(color.r) << 16) |
    (_linearToSrgb(color.g) << 8) |
    _linearToSrgb(color.b);

_Rgb _decodeDc(int value) => (
  r: _srgbToLinear((value >> 16) & 0xff),
  g: _srgbToLinear((value >> 8) & 0xff),
  b: _srgbToLinear(value & 0xff),
);

int _encodeAc(_Rgb color, double maximumValue) {
  int quantise(double value) =>
      (_signedPow(value / maximumValue, 0.5) * 9 + 9.5).floor().clamp(0, 18);
  return quantise(color.r) * 19 * 19 +
      quantise(color.g) * 19 +
      quantise(color.b);
}

_Rgb _decodeAc(int value, double maximumValue) {
  double dequantise(int quantised) =>
      _signedPow((quantised - 9) / 9, 2) * maximumValue;
  return (
    r: dequantise(value ~/ (19 * 19)),
    g: dequantise(value ~/ 19 % 19),
    b: dequantise(value % 19),
  );
}

double _signedPow(double value, double exponent) =>
    math.pow(value.abs(), exponent) * (value < 0 ? -1 : 1);

double _srgbToLinear(int value) {
  final v = value / 255;
  return v <= 0.04045
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4) as double;
}

int _linearToSrgb(double value) {
  final v = value.clamp(0.0, 1.0);
  return v <= 0.0031308
      ? (v * 12.92 * 255 + 0.5).round()
      : ((1.055 * math.pow(v, 1 / 2.4) - 0.055) * 255 + 0.5).round();
}

String _encode83(int value, int length) {
  final buffer = StringBuffer();
  for (var i = 1; i <= length; i++) {
    final digit = value ~/ math.pow(83, length - i).toInt() % 83;
    buffer.write(_digits[digit]);
  }
  return buffer.toString();
}

/// Null where [value] carries a character the alphabet does not.
int? _decode83(String value) {
  var result = 0;
  for (final character in value.split('')) {
    final digit = _digits.indexOf(character);
    if (digit < 0) return null;
    result = result * 83 + digit;
  }
  return result;
}
