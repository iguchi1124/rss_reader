import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rss_reader/data/repositories/feed_repository.dart';
import 'package:rss_reader/data/services/feed_api_client.dart';
import 'package:rss_reader/data/services/feed_database.dart';
import 'package:rss_reader/domain/models/feed.dart';
import 'package:rss_reader/utils/result.dart';

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
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late FeedDatabase database;

  setUp(() {
    database = FeedDatabase(databaseName: inMemoryDatabasePath);
  });

  tearDown(() => database.close());

  /// Serves [responses] by URL. Requested URLs accumulate in [requested] in
  /// call order.
  FeedRepository buildRepository(
    Map<String, String> responses, {
    List<String>? requested,
    int statusCode = 200,
  }) {
    final client = MockClient((request) async {
      requested?.add(request.url.toString());
      final body = responses[request.url.toString()];
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

    test(
      'marking read lowers the unread count and notifies listeners',
      () async {
        var notified = 0;
        repository.addListener(() => notified++);

        final article = (await repository.listArticles()).single;
        await repository.setRead(article.id, true);

        expect(await repository.unreadCount(), 0);
        expect(notified, greaterThan(0));
      },
    );

    test('stars and unstars an article', () async {
      final article = (await repository.listArticles()).single;

      await repository.setStarred(article.id, true);
      expect((await repository.findArticle(article.id))?.isStarred, isTrue);

      await repository.setStarred(article.id, false);
      expect((await repository.findArticle(article.id))?.isStarred, isFalse);
    });

    test('deleting a feed notifies listeners', () async {
      var notified = 0;
      repository.addListener(() => notified++);

      await repository.deleteFeed((await repository.listFeeds()).single.id);

      expect(await repository.listFeeds(), isEmpty);
      expect(notified, greaterThan(0));
    });
  });
}
