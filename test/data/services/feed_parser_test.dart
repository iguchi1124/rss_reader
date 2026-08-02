import 'package:flutter_test/flutter_test.dart';
import 'package:rss_reader/data/models/parsed_feed.dart';
import 'package:rss_reader/data/services/feed_parser.dart';
import 'package:rss_reader/utils/result.dart';

const _parser = FeedParser();

ParsedFeed _parse(String xml, {String? feedUrl}) {
  final result = _parser.parse(xml, feedUrl: feedUrl);
  expect(result, isA<Ok<ParsedFeed>>(), reason: 'expected the feed to parse');
  return (result as Ok<ParsedFeed>).value;
}

void main() {
  group('RSS 2.0', () {
    const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/"
     xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Test Blog</title>
    <link>https://example.com/</link>
    <description>Description &amp; test</description>
    <item>
      <title>First article</title>
      <link>/posts/1</link>
      <guid isPermaLink="false">tag:example.com,2026:1</guid>
      <description>&lt;p&gt;Excerpt text&lt;/p&gt;</description>
      <content:encoded>&lt;p&gt;The full body&lt;/p&gt;</content:encoded>
      <dc:creator>Author Name</dc:creator>
      <pubDate>Sun, 02 Aug 2026 14:48:00 +0900</pubDate>
    </item>
    <item>
      <title>Second article</title>
      <link>https://example.com/posts/2</link>
    </item>
  </channel>
</rss>
''';

    test('extracts channel details', () {
      final feed = _parse(xml);
      expect(feed.title, 'Test Blog');
      expect(feed.siteUrl, 'https://example.com/');
      expect(feed.description, 'Description & test');
      expect(feed.items, hasLength(2));
    });

    test('extracts each item field', () {
      final item = _parse(xml).items.first;
      expect(item.guid, 'tag:example.com,2026:1');
      expect(item.title, 'First article');
      expect(item.author, 'Author Name');
      expect(item.publishedAt, DateTime.utc(2026, 8, 2, 5, 48));
    });

    test('resolves relative links against the channel link', () {
      expect(_parse(xml).items.first.link, 'https://example.com/posts/1');
    });

    test(
      'uses content:encoded for the body and description for the excerpt',
      () {
        final item = _parse(xml).items.first;
        expect(item.content, contains('The full body'));
        expect(item.summary, 'Excerpt text');
      },
    );

    test('falls back to the link when guid is missing', () {
      expect(_parse(xml).items[1].guid, 'https://example.com/posts/2');
    });

    test('leaves the date null when absent', () {
      expect(_parse(xml).items[1].publishedAt, isNull);
    });
  });

  group('Atom', () {
    const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Atom Feed</title>
  <subtitle>Subtitle</subtitle>
  <link rel="self" href="https://example.com/atom.xml"/>
  <link rel="alternate" href="https://example.com/"/>
  <entry>
    <title>Atom article</title>
    <link rel="alternate" href="https://example.com/entry/1"/>
    <id>urn:uuid:1</id>
    <author><name>Atom Author</name></author>
    <published>2026-08-02T05:48:00Z</published>
    <updated>2026-08-03T00:00:00Z</updated>
    <content type="html">&lt;p&gt;Atom body&lt;/p&gt;</content>
  </entry>
</feed>
''';

    test(
      'extracts feed details and never picks rel="self" as the site URL',
      () {
        final feed = _parse(xml);
        expect(feed.title, 'Atom Feed');
        expect(feed.description, 'Subtitle');
        expect(feed.siteUrl, 'https://example.com/');
      },
    );

    test('extracts each entry field', () {
      final item = _parse(xml).items.single;
      expect(item.guid, 'urn:uuid:1');
      expect(item.title, 'Atom article');
      expect(item.link, 'https://example.com/entry/1');
      expect(item.author, 'Atom Author');
      expect(item.content, contains('Atom body'));
    });

    test('prefers published over updated', () {
      expect(
        _parse(xml).items.single.publishedAt,
        DateTime.utc(2026, 8, 2, 5, 48),
      );
    });

    test('uses updated when published is missing', () {
      const noPublished = '''
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>t</title>
  <entry><title>e</title><id>1</id><updated>2026-08-03T00:00:00Z</updated></entry>
</feed>
''';
      expect(
        _parse(noPublished).items.single.publishedAt,
        DateTime.utc(2026, 8, 3),
      );
    });
  });

  group('RSS 1.0 (RDF)', () {
    // Items sit outside channel, which is what distinguishes RSS 1.0.
    const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns="http://purl.org/rss/1.0/"
         xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel rdf:about="https://example.com/">
    <title>RDF Feed</title>
    <link>https://example.com/</link>
    <description>RDF description</description>
  </channel>
  <item rdf:about="https://example.com/rdf/1">
    <title>RDF article</title>
    <link>https://example.com/rdf/1</link>
    <description>RDF excerpt</description>
    <dc:date>2026-08-02T05:48:00Z</dc:date>
  </item>
</rdf:RDF>
''';

    test('picks up items that sit outside channel', () {
      final feed = _parse(xml);
      expect(feed.title, 'RDF Feed');
      expect(feed.items, hasLength(1));

      final item = feed.items.single;
      expect(item.title, 'RDF article');
      expect(item.summary, 'RDF excerpt');
      expect(item.publishedAt, DateTime.utc(2026, 8, 2, 5, 48));
    });
  });

  group('failures', () {
    test('fails on malformed XML', () {
      final result = _parser.parse('<rss><channel><title>never closed');
      expect(result, isA<Failure<ParsedFeed>>());
    });

    test('fails when the document is neither RSS nor Atom', () {
      final result = _parser.parse('<html><body>page</body></html>');
      expect(result, isA<Failure<ParsedFeed>>());
      expect(
        ((result as Failure<ParsedFeed>).error as FeedException).message,
        contains('Unsupported format'),
      );
    });

    test('falls back to the host name for an untitled feed', () {
      const xml =
          '<rss><channel><link>https://example.com/</link></channel></rss>';
      expect(
        _parse(xml, feedUrl: 'https://news.example.com/rss').title,
        'news.example.com',
      );
    });

    test('gives untitled items a display name', () {
      const xml =
          '<rss><channel><title>t</title><item><link>https://e.com/1</link></item></channel></rss>';
      expect(_parse(xml).items.single.title, '(untitled)');
    });
  });
}
