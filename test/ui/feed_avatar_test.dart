import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rss_reader/data/providers.dart';
import 'package:rss_reader/data/repositories/feed_repository.dart';
import 'package:rss_reader/data/services/feed_api_client.dart';
import 'package:rss_reader/data/services/feed_database.dart';
import 'package:rss_reader/ui/core/widgets/blur_hash_view.dart';
import 'package:rss_reader/ui/features/feeds/views/feed_list_screen.dart';

/// What the feed list falls back to, since nothing in a widget test can load
/// the icon itself: `Image.network` is served a 400 by the test HTTP client.
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

  /// Advances real asynchronous work and the widget tree together, the way
  /// every screen test here has to: SQLite runs outside the fake-async zone.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Subscribes to a feed with [iconBlurHash] already stored and draws the
  /// list.
  Future<void> pumpFeedList(
    WidgetTester tester, {
    required String title,
    String? iconBlurHash,
  }) async {
    final repository = FeedRepository(
      apiClient: FeedApiClient(
        httpClient: MockClient((_) async => http.Response('not found', 404)),
      ),
      database: database,
    );

    await tester.runAsync(
      () => database.insertFeed(
        title: title,
        feedUrl: 'https://example.com/feed.xml',
        iconUrl: 'https://example.com/icon.png',
        iconBlurHash: iconBlurHash,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [feedRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: FeedListScreen()),
      ),
    );
    await settle(tester);
  }

  testWidgets('draws the blur hash of an icon that will not load', (
    tester,
  ) async {
    await pumpFeedList(
      tester,
      title: 'Hashed Feed',
      iconBlurHash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
    );

    expect(find.byType(BlurHashView), findsOneWidget);
    expect(find.text('H'), findsNothing);
  });

  testWidgets('falls back to the initial with no hash to draw', (tester) async {
    await pumpFeedList(tester, title: 'Plain Feed');

    expect(find.byType(BlurHashView), findsNothing);
    expect(find.text('P'), findsOneWidget);
  });
}
