import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rss_reader/data/providers.dart';
import 'package:rss_reader/data/repositories/feed_repository.dart';
import 'package:rss_reader/data/services/feed_api_client.dart';
import 'package:rss_reader/data/services/feed_database.dart';
import 'package:rss_reader/ui/features/article_detail/view_models/article_detail_view_model.dart';
import 'package:rss_reader/ui/features/articles/view_models/article_list_view_model.dart';
import 'package:rss_reader/ui/features/feeds/view_models/feed_list_view_model.dart';

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

/// A write on one screen has to reach the others, which the providers no longer
/// learn about by listening to the repository.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late FeedDatabase database;
  late FeedRepository repository;
  late ProviderContainer container;

  setUp(() async {
    database = FeedDatabase(databaseName: inMemoryDatabasePath);
    repository = FeedRepository(
      apiClient: FeedApiClient(
        httpClient: MockClient(
          (request) async => http.Response.bytes(utf8.encode(_rss), 200),
        ),
      ),
      database: database,
    );
    container = ProviderContainer.test(
      overrides: [feedRepositoryProvider.overrideWithValue(repository)],
    );
    await container
        .read(feedListProvider.notifier)
        .addFeed('https://example.com/feed.xml');
  });

  tearDown(() => database.close());

  test('adding a feed reaches the unread badge', () async {
    await container.read(feedListProvider.future);

    expect(container.read(unreadCountProvider), 1);
  });

  test('marking an article read from the list updates the feed list', () async {
    final articles = await container.read(articleListProvider(null).future);
    await container
        .read(articleListProvider(null).notifier)
        .toggleRead(articles.single);

    expect(
      (await container.read(feedListProvider.future)).single.unreadCount,
      0,
    );
  });

  test(
    'marking an article read from the detail screen updates the list',
    () async {
      final articles = await container.read(articleListProvider(null).future);
      final article = articles.single;

      await container.read(articleProvider(article.id).notifier).setRead(true);

      final reloaded = await container.read(articleListProvider(null).future);
      expect(reloaded.single.isRead, isTrue);
      expect(container.read(unreadCountProvider), 0);
    },
  );

  test('deleting a feed empties the article list', () async {
    final feeds = await container.read(feedListProvider.future);
    await container.read(feedListProvider.notifier).deleteFeed(feeds.single);

    expect(await container.read(articleListProvider(null).future), isEmpty);
    expect(await container.read(feedListProvider.future), isEmpty);
  });
}
