import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rss_reader/data/providers.dart';
import 'package:rss_reader/data/repositories/feed_repository.dart';
import 'package:rss_reader/data/services/feed_api_client.dart';
import 'package:rss_reader/data/services/feed_database.dart';
import 'package:rss_reader/ui/features/home/views/home_screen.dart';

const _rss = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test Feed</title>
    <link>https://example.com/</link>
    <item>
      <title>Imported article</title>
      <link>https://example.com/1</link>
      <guid>1</guid>
      <description>Article excerpt</description>
      <pubDate>Sun, 02 Aug 2026 14:48:00 +0900</pubDate>
    </item>
  </channel>
</rss>
''';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late FeedDatabase database;
  late FeedRepository repository;

  setUp(() {
    database = FeedDatabase(databaseName: inMemoryDatabasePath);
    repository = FeedRepository(
      apiClient: FeedApiClient(
        httpClient: MockClient(
          (request) async => request.url.host == 'example.com'
              ? http.Response.bytes(utf8.encode(_rss), 200)
              : http.Response('not found', 404),
        ),
      ),
      database: database,
    );
  });

  tearDown(() => database.close());

  /// Advances real asynchronous work and the widget tree together.
  ///
  /// `pumpAndSettle` does not work here: SQLite runs outside the test's
  /// fake-async zone so it would never progress, and the loading spinner
  /// animates forever so the tree never settles. Interleaving `runAsync` with
  /// `pump` lets the database finish while still driving transitions.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [feedRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await settle(tester);
  }

  /// Runs repository work outside the fake-async zone so real I/O completes.
  Future<T> withRealAsync<T>(
    WidgetTester tester,
    Future<T> Function() body,
  ) async {
    final result = await tester.runAsync(body);
    await settle(tester);
    return result as T;
  }

  testWidgets('guides the user when there are no feeds', (tester) async {
    await pumpApp(tester);

    expect(find.text('No articles yet'), findsOneWidget);

    await tester.tap(find.text('Feeds'));
    await settle(tester);
    expect(find.text('No feeds yet'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('adding a feed by URL lists its articles', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Feeds'));
    await settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Add feed'));
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'https://example.com/rss');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    // Registered in the feed list and counted as one unread article.
    expect(find.text('Test Feed'), findsWidgets);
    expect(find.text('1'), findsWidgets);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.text('Latest'));
    await settle(tester);
    expect(find.text('Imported article'), findsOneWidget);
    expect(find.text('Article excerpt'), findsOneWidget);
  });

  testWidgets('shows the reason in the dialog when adding fails', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Feeds'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Add feed'));
    await settle(tester);

    await tester.enterText(
      find.byType(TextField),
      'https://missing.example/rss',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    // The dialog stays open so the reason remains visible.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('HTTP 404'), findsOneWidget);
  });

  testWidgets('tapping an article opens it and marks it read', (tester) async {
    await tester.runAsync(() => repository.addFeed('https://example.com/rss'));
    await pumpApp(tester);

    expect(await withRealAsync(tester, repository.unreadCount), 1);

    await tester.tap(find.text('Imported article'));
    await settle(tester);

    // An action only the detail screen has, confirming the push happened.
    expect(find.byTooltip('Open in browser'), findsOneWidget);
    expect(await withRealAsync(tester, repository.unreadCount), 0);
  });

  testWidgets('filtering to unread hides articles already read', (
    tester,
  ) async {
    await tester.runAsync(() => repository.addFeed('https://example.com/rss'));
    await pumpApp(tester);

    final article = await withRealAsync(
      tester,
      () async => (await repository.listArticles()).single,
    );
    await withRealAsync(tester, () => repository.setRead(article.id, true));

    await tester.tap(find.text('Unread'));
    await settle(tester);

    expect(find.text('Imported article'), findsNothing);
    expect(find.text('No unread articles'), findsOneWidget);
  });

  testWidgets('a starred article survives the starred filter', (tester) async {
    await tester.runAsync(() => repository.addFeed('https://example.com/rss'));
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Add star').first);
    await settle(tester);

    await tester.tap(find.text('Starred'));
    await settle(tester);

    expect(find.text('Imported article'), findsOneWidget);
  });
}
