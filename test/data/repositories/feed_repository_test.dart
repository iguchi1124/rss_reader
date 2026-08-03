import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rss_reader/data/repositories/feed_repository.dart';
import 'package:rss_reader/data/services/feed_api_client.dart';
import 'package:rss_reader/data/services/feed_database.dart';
import 'package:rss_reader/domain/models/feed.dart';
import 'package:rss_reader/utils/blur_hash.dart';
import 'package:rss_reader/utils/result.dart';

import '../../support/test_images.dart';

const _rss = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test Feed</title>
    <link>https://example.com/</link>
    <item>
      <title>First</title>
      <link>https://example.com/1</link>
      <guid>1</guid>
    </item>
  </channel>
</rss>
''';

const _rssWithTwoItems = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Updated title</title>
    <link>https://example.com/</link>
    <item><title>First</title><guid>1</guid></item>
    <item><title>Second</title><guid>2</guid></item>
  </channel>
</rss>
''';

const _htmlWithFeedLink = '''
<html><head>
  <link rel="alternate" type="application/rss+xml" href="/feed.xml"/>
</head><body>body</body></html>
''';

void main() {
  setUpAll(() {
    // Hashing an icon decodes it through the engine.
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late FeedDatabase database;

  setUp(() {
    database = FeedDatabase(databaseName: inMemoryDatabasePath);
  });

  tearDown(() => database.close());

  /// Serves [responses] by URL, and [images] by URL for the icon downloads
  /// that hashing makes. Requested URLs accumulate in [requested] in call
  /// order.
  FeedRepository buildRepository(
    Map<String, String> responses, {
    Map<String, Uint8List>? images,
    List<String>? requested,
    int statusCode = 200,
  }) {
    final client = MockClient((request) async {
      final url = request.url.toString();
      requested?.add(url);

      final image = images?[url];
      if (image != null) {
        return http.Response.bytes(
          image,
          statusCode,
          headers: {'content-type': 'image/png'},
        );
      }

      final body = responses[url];
      if (body == null) return http.Response('not found', 404);
      return http.Response.bytes(
        utf8.encode(body),
        statusCode,
        headers: {'content-type': 'application/xml'},
      );
    });

    return FeedRepository(
      apiClient: FeedApiClient(httpClient: client),
      database: database,
    );
  }

  group('addFeed', () {
    test('stores the feed and its articles', () async {
      final repository = buildRepository({
        'https://example.com/feed.xml': _rss,
      });

      final result = await repository.addFeed('https://example.com/feed.xml');

      expect(result, isA<Ok<Feed>>());
      expect((result as Ok<Feed>).value.title, 'Test Feed');
      expect(await repository.listArticles(), hasLength(1));
    });

    test('treats input without a scheme as https', () async {
      final repository = buildRepository({
        'https://example.com/feed.xml': _rss,
      });

      expect(await repository.addFeed('example.com/feed.xml'), isA<Ok<Feed>>());
    });

    test('discovers the feed behind a site URL', () async {
      final requested = <String>[];
      final repository = buildRepository({
        'https://example.com/': _htmlWithFeedLink,
        'https://example.com/feed.xml': _rss,
      }, requested: requested);

      final result = await repository.addFeed('https://example.com/');

      expect(result, isA<Ok<Feed>>());
      // The HTML page is fetched first, then the feed it advertises.
      expect(requested, [
        'https://example.com/',
        'https://example.com/feed.xml',
      ]);
      expect(
        (await repository.listFeeds()).single.feedUrl,
        'https://example.com/feed.xml',
      );
    });

    test('refuses to subscribe to the same feed twice', () async {
      final repository = buildRepository({
        'https://example.com/feed.xml': _rss,
      });
      await repository.addFeed('https://example.com/feed.xml');

      final result = await repository.addFeed('https://example.com/feed.xml');

      expect(result, isA<Failure<Feed>>());
      expect(
        ((result as Failure<Feed>).error as FeedException).message,
        contains('already subscribe'),
      );
      expect(await repository.listFeeds(), hasLength(1));
    });

    test('does not subscribe when the fetch fails', () async {
      final repository = buildRepository(const {});

      final result = await repository.addFeed('https://example.com/feed.xml');

      expect(result, isA<Failure<Feed>>());
      expect(await repository.listFeeds(), isEmpty);
    });

    test('reports the parse error for a page that is not a feed', () async {
      final repository = buildRepository({
        'https://example.com/': '<html><body>no feed link here</body></html>',
      });

      final result = await repository.addFeed('https://example.com/');

      expect(result, isA<Failure<Feed>>());
      expect(
        ((result as Failure<Feed>).error as FeedException).message,
        contains('Unsupported format'),
      );
    });

    test('does not make a request for a malformed URL', () async {
      final requested = <String>[];
      final repository = buildRepository(const {}, requested: requested);

      expect(await repository.addFeed('   '), isA<Failure<Feed>>());
      expect(requested, isEmpty);
    });
  });

  group('feed icons', () {
    const rssWithImage = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test Feed</title>
    <link>https://example.com/</link>
    <image><url>https://example.com/logo.png</url></image>
    <item><title>First</title><guid>1</guid></item>
  </channel>
</rss>
''';

    const htmlWithFeedAndIcon = '''
<html><head>
  <link rel="alternate" type="application/rss+xml" href="/feed.xml"/>
  <link rel="icon" sizes="192x192" href="/icon.png"/>
</head><body>body</body></html>
''';

    test('takes the image the feed declares without asking the site', () async {
      final requested = <String>[];
      final repository = buildRepository(
        {'https://example.com/feed.xml': rssWithImage},
        images: {'https://example.com/logo.png': await pngBytes()},
        requested: requested,
      );

      await repository.addFeed('https://example.com/feed.xml');

      expect(
        (await repository.listFeeds()).single.iconUrl,
        'https://example.com/logo.png',
      );
      // The site is not asked for anything; the image itself is downloaded
      // once, which is the only way to hash it.
      expect(requested, [
        'https://example.com/feed.xml',
        'https://example.com/logo.png',
      ]);
    });

    test('reads the icon out of the page it already fetched', () async {
      final requested = <String>[];
      final repository = buildRepository(
        {
          'https://example.com/': htmlWithFeedAndIcon,
          'https://example.com/feed.xml': _rss,
        },
        images: {'https://example.com/icon.png': await pngBytes()},
        requested: requested,
      );

      await repository.addFeed('https://example.com/');

      expect(
        (await repository.listFeeds()).single.iconUrl,
        'https://example.com/icon.png',
      );
      // The site page is not fetched a second time for the icon; the icon
      // itself is, to hash it.
      expect(requested, [
        'https://example.com/',
        'https://example.com/feed.xml',
        'https://example.com/icon.png',
      ]);
    });

    test('goes to the site when the feed declares no image', () async {
      final requested = <String>[];
      final repository = buildRepository(
        {
          'https://example.com/feed.xml': _rss,
          'https://example.com/': htmlWithFeedAndIcon,
        },
        images: {'https://example.com/icon.png': await pngBytes()},
        requested: requested,
      );

      await repository.addFeed('https://example.com/feed.xml');

      expect(
        (await repository.listFeeds()).single.iconUrl,
        'https://example.com/icon.png',
      );
      expect(requested, [
        'https://example.com/feed.xml',
        'https://example.com/',
        'https://example.com/icon.png',
      ]);
    });

    test('passes over a declared icon that cannot be drawn', () async {
      // An Atom icon pointing at the favicon is common, and dart:ui has no ICO
      // codec, so the site's PNG is the better answer.
      const atomWithIcoIcon = '''
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Test Feed</title>
  <icon>https://example.com/favicon.ico</icon>
  <link rel="alternate" href="https://example.com/"/>
  <entry><title>First</title><id>1</id></entry>
</feed>
''';

      final repository = buildRepository({
        'https://example.com/feed.xml': atomWithIcoIcon,
        'https://example.com/': htmlWithFeedAndIcon,
      });

      await repository.addFeed('https://example.com/feed.xml');

      expect(
        (await repository.listFeeds()).single.iconUrl,
        'https://example.com/icon.png',
      );
    });

    test('leaves the icon null when nothing offers one', () async {
      final repository = buildRepository({
        'https://example.com/feed.xml': _rss,
      });

      await repository.addFeed('https://example.com/feed.xml');

      expect((await repository.listFeeds()).single.iconUrl, isNull);
    });

    test('keeps a stored icon instead of looking again', () async {
      final requested = <String>[];
      final repository = buildRepository(
        {
          'https://example.com/feed.xml': _rss,
          'https://example.com/': htmlWithFeedAndIcon,
        },
        images: {'https://example.com/icon.png': await pngBytes()},
        requested: requested,
      );
      await repository.addFeed('https://example.com/feed.xml');

      requested.clear();
      final feed = (await repository.listFeeds()).single;
      await repository.refreshFeed(feed);

      expect(
        (await repository.listFeeds()).single.iconUrl,
        'https://example.com/icon.png',
      );
      expect(requested, ['https://example.com/feed.xml']);
    });

    group('blur hashes', () {
      test('hashes the icon it stored', () async {
        final repository = buildRepository(
          {'https://example.com/feed.xml': rssWithImage},
          images: {'https://example.com/logo.png': await pngBytes()},
        );

        await repository.addFeed('https://example.com/feed.xml');

        final hash = (await repository.listFeeds()).single.iconBlurHash;
        expect(decodeBlurHash(hash!, width: 4, height: 4), isNotNull);
      });

      test('keeps the icon when the image cannot be hashed', () async {
        // Nothing serves the image here. The URL is still worth storing: the
        // list may well reach it even when this did not.
        final repository = buildRepository({
          'https://example.com/feed.xml': rssWithImage,
        });

        await repository.addFeed('https://example.com/feed.xml');

        final feed = (await repository.listFeeds()).single;
        expect(feed.iconUrl, 'https://example.com/logo.png');
        expect(feed.iconBlurHash, isNull);
      });

      test('replaces the hash when the icon moves', () async {
        final responses = {'https://example.com/feed.xml': rssWithImage};
        final repository = buildRepository(
          responses,
          images: {
            'https://example.com/logo.png': await pngBytes(),
            'https://example.com/logo-v2.png': await pngBytes(
              top: const Color(0xff2244aa),
              bottom: const Color(0xffddaa22),
            ),
          },
        );
        await repository.addFeed('https://example.com/feed.xml');
        final before = (await repository.listFeeds()).single;

        responses['https://example.com/feed.xml'] = rssWithImage.replaceAll(
          'logo.png',
          'logo-v2.png',
        );
        await repository.refreshFeed(before);

        final after = (await repository.listFeeds()).single;
        expect(after.iconUrl, 'https://example.com/logo-v2.png');
        expect(after.iconBlurHash, isNotNull);
        expect(after.iconBlurHash, isNot(before.iconBlurHash));
      });

      test('hashes an icon that was stored without one', () async {
        // The path a feed subscribed to before the column existed takes, and
        // the one a feed whose image failed to download takes again.
        final requested = <String>[];
        final repository = buildRepository(
          {'https://example.com/feed.xml': _rss},
          images: {'https://example.com/icon.png': await pngBytes()},
          requested: requested,
        );
        await database.insertFeed(
          title: 'Test Feed',
          feedUrl: 'https://example.com/feed.xml',
          iconUrl: 'https://example.com/icon.png',
        );

        await repository.refreshFeed((await repository.listFeeds()).single);

        expect((await repository.listFeeds()).single.iconBlurHash, isNotNull);
        expect(requested, contains('https://example.com/icon.png'));
      });
    });
  });

  group('refreshFeed', () {
    test('returns the new-article count and updates feed metadata', () async {
      var body = _rss;
      final repository = FeedRepository(
        apiClient: FeedApiClient(
          httpClient: MockClient(
            (_) async => http.Response.bytes(utf8.encode(body), 200),
          ),
        ),
        database: database,
      );
      await repository.addFeed('https://example.com/feed.xml');

      body = _rssWithTwoItems;
      final feed = (await repository.listFeeds()).single;
      final result = await repository.refreshFeed(feed);

      expect(result, isA<Ok<int>>());
      expect(
        (result as Ok<int>).value,
        1,
        reason: 'only the one added article counts',
      );

      final updated = (await repository.listFeeds()).single;
      expect(updated.title, 'Updated title');
      expect(updated.totalCount, 2);
      expect(updated.lastFetchedAt, isNotNull);
    });

    test('keeps existing articles when the fetch fails', () async {
      var fail = false;
      final repository = FeedRepository(
        apiClient: FeedApiClient(
          httpClient: MockClient(
            (_) async => fail
                ? http.Response('error', 500)
                : http.Response.bytes(utf8.encode(_rss), 200),
          ),
        ),
        database: database,
      );
      await repository.addFeed('https://example.com/feed.xml');

      fail = true;
      final feed = (await repository.listFeeds()).single;
      final result = await repository.refreshFeed(feed);

      expect(result, isA<Failure<int>>());
      expect(await repository.listArticles(), hasLength(1));
    });
  });

  group('refreshAll', () {
    test('refreshes the rest and reports the failures', () async {
      final repository = buildRepository({
        'https://good.example/feed.xml': _rss,
        'https://bad.example/feed.xml': _rss,
      });
      await repository.addFeed('https://good.example/feed.xml');
      await repository.addFeed('https://bad.example/feed.xml');

      // Rebuilt over a client where only one of the two hosts fails.
      final flaky = FeedRepository(
        apiClient: FeedApiClient(
          httpClient: MockClient((request) async {
            if (request.url.host == 'bad.example') {
              return http.Response('error', 500);
            }
            return http.Response.bytes(utf8.encode(_rssWithTwoItems), 200);
          }),
        ),
        database: database,
      );

      final summary = await flaky.refreshAll();

      expect(summary.refreshedFeeds, 2);
      expect(summary.newArticles, 1);
      expect(summary.failedFeeds, hasLength(1));
      expect(summary.message, contains('1 feed(s) failed to update'));
    });

    test('says so when there are no feeds', () async {
      final repository = buildRepository(const {});
      expect((await repository.refreshAll()).message, contains('No feeds yet'));
    });
  });

  group('state changes', () {
    late FeedRepository repository;

    setUp(() async {
      repository = buildRepository({'https://example.com/feed.xml': _rss});
      await repository.addFeed('https://example.com/feed.xml');
    });

    test('marking read lowers the unread count', () async {
      final article = (await repository.listArticles()).single;
      await repository.setRead(article.id, true);

      expect(await repository.unreadCount(), 0);
    });

    test('stars and unstars an article', () async {
      final article = (await repository.listArticles()).single;

      await repository.setStarred(article.id, true);
      expect((await repository.findArticle(article.id))?.isStarred, isTrue);

      await repository.setStarred(article.id, false);
      expect((await repository.findArticle(article.id))?.isStarred, isFalse);
    });

    test('deleting a feed drops it from the list', () async {
      await repository.deleteFeed((await repository.listFeeds()).single.id);

      expect(await repository.listFeeds(), isEmpty);
    });
  });
}
