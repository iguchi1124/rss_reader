import 'package:flutter_test/flutter_test.dart';
import 'package:rss_reader/data/services/feed_date_parser.dart';

void main() {
  group('parseFeedDate', () {
    test('reads Atom ISO 8601 as UTC', () {
      expect(
        parseFeedDate('2026-08-02T14:48:00+09:00'),
        DateTime.utc(2026, 8, 2, 5, 48),
      );
    });

    test('reads RSS RFC 822 with a numeric offset', () {
      expect(
        parseFeedDate('Sun, 02 Aug 2026 14:48:00 +0900'),
        DateTime.utc(2026, 8, 2, 5, 48),
      );
    });

    test('handles negative offsets', () {
      expect(
        parseFeedDate('Sun, 02 Aug 2026 09:30:00 -0530'),
        DateTime.utc(2026, 8, 2, 15, 0),
      );
    });

    test('handles named time zones', () {
      expect(
        parseFeedDate('Sun, 02 Aug 2026 14:48:00 GMT'),
        DateTime.utc(2026, 8, 2, 14, 48),
      );
      expect(
        parseFeedDate('Sun, 02 Aug 2026 09:00:00 EST'),
        DateTime.utc(2026, 8, 2, 14, 0),
      );
    });

    test('allows weekday, seconds, and zone to be omitted', () {
      expect(
        parseFeedDate('2 Aug 2026 14:48'),
        DateTime.utc(2026, 8, 2, 14, 48),
      );
    });

    test('expands two-digit years', () {
      expect(parseFeedDate('02 Aug 99 00:00:00 GMT')?.year, 1999);
      expect(parseFeedDate('02 Aug 26 00:00:00 GMT')?.year, 2026);
    });

    test('returns null for values it cannot parse', () {
      expect(parseFeedDate(null), isNull);
      expect(parseFeedDate(''), isNull);
      expect(parseFeedDate('   '), isNull);
      expect(parseFeedDate('yesterday'), isNull);
      expect(parseFeedDate('Sun, 02 Xxx 2026 14:48:00 +0900'), isNull);
    });
  });
}
