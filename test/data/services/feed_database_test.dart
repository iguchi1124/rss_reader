import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rss_reader/data/services/feed_database.dart';
import 'package:rss_reader/domain/models/article.dart';

void main() {
  // Runs SQLite on the host instead of requiring a device.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late FeedDatabase database;
  late int feedId;

  setUp(() async {
    // In-memory means every test starts from an empty database.
    database = FeedDatabase(databaseName: inMemoryDatabasePath);
    feedId = await database.insertFeed(
      title: 'Test Feed',
      feedUrl: 'https://example.com/feed.xml',
      siteUrl: 'https://example.com/',
    );
  });

  tearDown(() => database.close());

  ArticleRecord record(String guid, {String? title, DateTime? publishedAt}) =>
      ArticleRecord(
        guid: guid,
        title: title ?? 'Article $guid',
        link: 'https://example.com/$guid',
        publishedAt: publishedAt,
      );

  group('feeds', () {
    test('aggregates unread and total counts', () async {
      await database.upsertArticles(feedId, [
        record('a'),
        record('b'),
      ], fetchedAt: DateTime.now());

      final articles = await database.listArticles();
      await database.setRead(articles.first.id, true);

      final feed = (await database.listFeeds()).single;
      expect(feed.totalCount, 2);
      expect(feed.unreadCount, 1);
    });

    test('lists feeds that have no articles', () async {
      final feed = (await database.listFeeds()).single;
      expect(feed.title, 'Test Feed');
      expect(feed.totalCount, 0);
      expect(feed.unreadCount, 0);
    });

    test('looks up an existing feed by URL', () async {
      expect(
        (await database.findFeedByUrl('https://example.com/feed.xml'))?.id,
        feedId,
      );
      expect(
        await database.findFeedByUrl('https://other.example/feed'),
        isNull,
      );
    });

    test('deleting a feed deletes its articles', () async {
      await database.upsertArticles(feedId, [
        record('a'),
      ], fetchedAt: DateTime.now());

      await database.deleteFeed(feedId);

      expect(await database.listFeeds(), isEmpty);
      expect(await database.listArticles(), isEmpty);
    });
  });

  group('feed icons', () {
    test('round-trip through insert and update', () async {
      const feedUrl = 'https://iconed.example/feed.xml';

      final id = await database.insertFeed(
        title: 'Iconed',
        feedUrl: feedUrl,
        iconUrl: 'https://iconed.example/icon.png',
      );
      expect(
        (await database.findFeedByUrl(feedUrl))?.iconUrl,
        'https://iconed.example/icon.png',
      );

      await database.updateFeedMetadata(
        feedId: id,
        title: 'Iconed',
        iconUrl: 'https://iconed.example/moved.png',
        fetchedAt: DateTime.now(),
      );
      expect(
        (await database.findFeedByUrl(feedUrl))?.iconUrl,
        'https://iconed.example/moved.png',
      );
    });

    test('a refresh that finds no icon keeps the stored one', () async {
      const feedUrl = 'https://iconed.example/feed.xml';

      final id = await database.insertFeed(
        title: 'Iconed',
        feedUrl: feedUrl,
        iconUrl: 'https://iconed.example/icon.png',
        iconBlurHash: 'L6PZfSjE.AyE_3t7t7R**0o#DgR4',
      );

      await database.updateFeedMetadata(
        feedId: id,
        title: 'Iconed',
        fetchedAt: DateTime.now(),
      );

      final feed = await database.findFeedByUrl(feedUrl);
      expect(feed?.iconUrl, 'https://iconed.example/icon.png');
      expect(feed?.iconBlurHash, 'L6PZfSjE.AyE_3t7t7R**0o#DgR4');
    });

    test('the blur hash follows the icon it belongs to', () async {
      const feedUrl = 'https://iconed.example/feed.xml';

      final id = await database.insertFeed(
        title: 'Iconed',
        feedUrl: feedUrl,
        iconUrl: 'https://iconed.example/icon.png',
        iconBlurHash: 'L6PZfSjE.AyE_3t7t7R**0o#DgR4',
      );

      await database.updateFeedMetadata(
        feedId: id,
        title: 'Iconed',
        iconUrl: 'https://iconed.example/moved.png',
        iconBlurHash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
        fetchedAt: DateTime.now(),
      );

      final feed = await database.findFeedByUrl(feedUrl);
      expect(feed?.iconUrl, 'https://iconed.example/moved.png');
      expect(feed?.iconBlurHash, 'LEHV6nWB2yk8pyo0adR*.7kCMdnj');
    });

    test('a new icon with no hash clears the old hash', () async {
      // Leaving the previous one behind would blur the wrong image under the
      // new icon.
      const feedUrl = 'https://iconed.example/feed.xml';

      final id = await database.insertFeed(
        title: 'Iconed',
        feedUrl: feedUrl,
        iconUrl: 'https://iconed.example/icon.png',
        iconBlurHash: 'L6PZfSjE.AyE_3t7t7R**0o#DgR4',
      );

      await database.updateFeedMetadata(
        feedId: id,
        title: 'Iconed',
        iconUrl: 'https://iconed.example/moved.png',
        fetchedAt: DateTime.now(),
      );

      expect((await database.findFeedByUrl(feedUrl))?.iconBlurHash, isNull);
    });

    test('a database written before the column existed still opens', () async {
      // In-memory databases cannot be reopened, so the upgrade needs a file.
      final directory = await Directory.systemTemp.createTemp('rss_reader_v1');
      addTearDown(() => directory.delete(recursive: true));

      final path = p.join(directory.path, 'legacy.db');
      final legacy = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          // Version 1's tables, where feeds had no icon_url. The indexes are
          // left out: they play no part in the upgrade.
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE feeds (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                feed_url TEXT NOT NULL UNIQUE,
                site_url TEXT,
                description TEXT,
                last_fetched_at INTEGER
              )
            ''');
            await db.execute('''
              CREATE TABLE articles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                feed_id INTEGER NOT NULL
                  REFERENCES feeds (id) ON DELETE CASCADE,
                guid TEXT NOT NULL,
                title TEXT NOT NULL,
                link TEXT,
                author TEXT,
                summary TEXT,
                content TEXT,
                published_at INTEGER,
                fetched_at INTEGER NOT NULL,
                is_read INTEGER NOT NULL DEFAULT 0,
                is_starred INTEGER NOT NULL DEFAULT 0,
                UNIQUE (feed_id, guid)
              )
            ''');
          },
        ),
      );
      await legacy.insert('feeds', {
        'title': 'Subscribed before icons',
        'feed_url': 'https://legacy.example/feed.xml',
      });
      await legacy.close();

      final upgraded = FeedDatabase(databaseName: path);
      addTearDown(upgraded.close);

      final feed = (await upgraded.listFeeds()).single;
      expect(feed.title, 'Subscribed before icons');
      expect(feed.iconUrl, isNull);
      expect(feed.iconBlurHash, isNull);
    });

    test('a database written before the hash existed keeps its icon', () async {
      final directory = await Directory.systemTemp.createTemp('rss_reader_v2');
      addTearDown(() => directory.delete(recursive: true));

      final path = p.join(directory.path, 'legacy.db');
      final legacy = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          // Version 2's feeds table, which had icon_url but no hash beside it.
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE feeds (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                feed_url TEXT NOT NULL UNIQUE,
                site_url TEXT,
                icon_url TEXT,
                description TEXT,
                last_fetched_at INTEGER
              )
            ''');
            await db.execute('''
              CREATE TABLE articles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                feed_id INTEGER NOT NULL
                  REFERENCES feeds (id) ON DELETE CASCADE,
                guid TEXT NOT NULL,
                title TEXT NOT NULL,
                link TEXT,
                author TEXT,
                summary TEXT,
                content TEXT,
                published_at INTEGER,
                fetched_at INTEGER NOT NULL,
                is_read INTEGER NOT NULL DEFAULT 0,
                is_starred INTEGER NOT NULL DEFAULT 0,
                UNIQUE (feed_id, guid)
              )
            ''');
          },
        ),
      );
      await legacy.insert('feeds', {
        'title': 'Subscribed before hashes',
        'feed_url': 'https://legacy.example/feed.xml',
        'icon_url': 'https://legacy.example/icon.png',
      });
      await legacy.close();

      final upgraded = FeedDatabase(databaseName: path);
      addTearDown(upgraded.close);

      final feed = (await upgraded.listFeeds()).single;
      expect(feed.iconUrl, 'https://legacy.example/icon.png');
      expect(feed.iconBlurHash, isNull);
    });
  });

  group('storing articles', () {
    test('returns how many articles were new', () async {
      final added = await database.upsertArticles(feedId, [
        record('a'),
        record('b'),
      ], fetchedAt: DateTime.now());
      expect(added, 2);
    });

    test('does not duplicate or recount the same guid', () async {
      await database.upsertArticles(feedId, [
        record('a'),
      ], fetchedAt: DateTime.now());

      final added = await database.upsertArticles(feedId, [
        record('a'),
        record('b'),
      ], fetchedAt: DateTime.now());

      expect(added, 1);
      expect(await database.listArticles(), hasLength(2));
    });

    test('keeps read and starred state across a re-fetch', () async {
      await database.upsertArticles(feedId, [
        record('a'),
      ], fetchedAt: DateTime.now());

      final article = (await database.listArticles()).single;
      await database.setRead(article.id, true);
      await database.setStarred(article.id, true);

      // The publisher corrected the title after the article was first stored.
      await database.upsertArticles(feedId, [
        record('a', title: 'Corrected title'),
      ], fetchedAt: DateTime.now());

      final updated = (await database.listArticles()).single;
      expect(updated.title, 'Corrected title');
      expect(updated.isRead, isTrue);
      expect(updated.isStarred, isTrue);
    });
  });

  group('reading articles', () {
    setUp(() async {
      await database.upsertArticles(feedId, [
        record('old', publishedAt: DateTime.utc(2026, 1, 1)),
        record('new', publishedAt: DateTime.utc(2026, 8, 1)),
      ], fetchedAt: DateTime.now());
    });

    test('orders by publication date, newest first', () async {
      final articles = await database.listArticles();
      expect(articles.map((a) => a.guid), ['new', 'old']);
    });

    test('includes the feed title', () async {
      expect((await database.listArticles()).first.feedTitle, 'Test Feed');
    });

    test('filters to unread', () async {
      final articles = await database.listArticles();
      await database.setRead(articles.first.id, true);

      final unread = await database.listArticles(filter: ArticleFilter.unread);
      expect(unread.map((a) => a.guid), ['old']);
    });

    test('filters to starred', () async {
      final articles = await database.listArticles();
      await database.setStarred(articles.first.id, true);

      final starred = await database.listArticles(
        filter: ArticleFilter.starred,
      );
      expect(starred.map((a) => a.guid), ['new']);
    });

    test('does not mix in articles from another feed', () async {
      final otherId = await database.insertFeed(
        title: 'Other Feed',
        feedUrl: 'https://other.example/feed.xml',
      );
      await database.upsertArticles(otherId, [
        record('other'),
      ], fetchedAt: DateTime.now());

      final scoped = await database.listArticles(feedId: feedId);
      expect(scoped.map((a) => a.guid), ['new', 'old']);
      expect(await database.listArticles(), hasLength(3));
    });

    test('limits the number of rows', () async {
      expect(await database.listArticles(limit: 1), hasLength(1));
    });
  });

  group('marking many as read', () {
    late int otherId;

    setUp(() async {
      otherId = await database.insertFeed(
        title: 'Other Feed',
        feedUrl: 'https://other.example/feed.xml',
      );
      await database.upsertArticles(feedId, [
        record('a'),
      ], fetchedAt: DateTime.now());
      await database.upsertArticles(otherId, [
        record('b'),
      ], fetchedAt: DateTime.now());
    });

    test('marks only the given feed when one is specified', () async {
      await database.markAllRead(feedId: feedId);
      expect(await database.unreadCount(), 1);
    });

    test('marks every article when no feed is given', () async {
      await database.markAllRead();
      expect(await database.unreadCount(), 0);
    });
  });
}
