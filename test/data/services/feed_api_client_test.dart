import 'package:flutter_test/flutter_test.dart';
import 'package:rss_reader/data/services/feed_api_client.dart';

void main() {
  final client = FeedApiClient();

  tearDownAll(client.dispose);

  String? iconIn(String head) => client.discoverIconUrl(
    '<html><head>$head</head><body></body></html>',
    baseUrl: 'https://example.com/blog/',
  );

  group('discoverIconUrl', () {
    test('takes rel="icon" and resolves it against the page', () {
      expect(
        iconIn('<link rel="icon" href="/icon.png">'),
        'https://example.com/icon.png',
      );
    });

    test('accepts the older rel="shortcut icon"', () {
      expect(
        iconIn('<link rel="shortcut icon" href="/icon.png">'),
        'https://example.com/icon.png',
      );
    });

    test('prefers the largest declared size', () {
      expect(
        iconIn('''
<link rel="icon" sizes="16x16" href="/small.png">
<link rel="icon" sizes="192x192" href="/large.png">
'''),
        'https://example.com/large.png',
      );
    });

    test('treats an apple-touch-icon as 180 when it declares no size', () {
      expect(
        iconIn('''
<link rel="icon" sizes="32x32" href="/small.png">
<link rel="apple-touch-icon" href="/touch.png">
'''),
        'https://example.com/touch.png',
      );
    });

    // Storing one would only fail on every build: dart:ui has no codec for
    // either format.
    test('skips icons that cannot be drawn', () {
      expect(iconIn('<link rel="icon" href="/favicon.ico">'), isNull);
      expect(iconIn('<link rel="icon" href="/icon.svg">'), isNull);
      expect(
        iconIn('<link rel="icon" type="image/x-icon" href="/favicon">'),
        isNull,
      );
    });

    test('ignores links that are not icons', () {
      expect(
        iconIn('''
<link rel="stylesheet" href="/app.css">
<link rel="mask-icon" href="/mask.svg">
<link rel="alternate" type="application/rss+xml" href="/feed.xml">
'''),
        isNull,
      );
    });

    test('returns null for a page carrying no icon', () {
      expect(iconIn(''), isNull);
    });
  });
}
