import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/models/article.dart';
import '../../domain/models/feed.dart';

/// All SQLite reads and writes.
///
/// Maps between rows and domain models; holds no business logic.
class FeedDatabase {
  FeedDatabase({String? databaseName})
    : _databaseName = databaseName ?? 'rss_reader.db';

  final String _databaseName;
  Database? _database;

  Future<Database> get _db async => _database ??= await _open();

  Future<Database> _open() async {
    // Tests pass the in-memory sentinel, which must not be joined with a path.
    final path = _databaseName == inMemoryDatabasePath
        ? _databaseName
        : p.join(await getDatabasesPath(), _databaseName);

    return openDatabase(
      path,
      version: 2,
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
      onConfigure: (db) async {
        // Required for articles to cascade on feed delete. sqflite needs this
        // set per connection.
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createSchema(Database db, int version) async {
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
        feed_id INTEGER NOT NULL REFERENCES feeds (id) ON DELETE CASCADE,
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

    // Lists are read two ways: per feed, and across all feeds newest first.
    await db.execute(
      'CREATE INDEX idx_articles_feed ON articles (feed_id, published_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_articles_published ON articles (published_at DESC)',
    );
  }

  /// Existing rows keep a null `icon_url` and pick one up on their next
  /// refresh, which is also the path a feed that never had one takes.
  Future<void> _upgradeSchema(Database db, int from, int to) async {
    if (from < 2) {
      await db.execute('ALTER TABLE feeds ADD COLUMN icon_url TEXT');
    }
  }

  // --- Feeds ----------------------------------------------------------------

  /// Returns subscribed feeds with their unread and total counts.
  Future<List<Feed>> listFeeds() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        f.*,
        COUNT(a.id) AS total_count,
        COUNT(CASE WHEN a.is_read = 0 THEN 1 END) AS unread_count
      FROM feeds f
      LEFT JOIN articles a ON a.feed_id = f.id
      GROUP BY f.id
      ORDER BY f.title COLLATE NOCASE ASC
    ''');
    return rows.map(_feedFromRow).toList();
  }

  Future<Feed?> findFeedByUrl(String feedUrl) async {
    final db = await _db;
    final rows = await db.query(
      'feeds',
      where: 'feed_url = ?',
      whereArgs: [feedUrl],
      limit: 1,
    );
    return rows.isEmpty ? null : _feedFromRow(rows.first);
  }

  /// Inserts a feed and returns its generated id.
  Future<int> insertFeed({
    required String title,
    required String feedUrl,
    String? siteUrl,
    String? iconUrl,
    String? description,
  }) async {
    final db = await _db;
    return db.insert('feeds', {
      'title': title,
      'feed_url': feedUrl,
      'site_url': siteUrl,
      'icon_url': iconUrl,
      'description': description,
    });
  }

  Future<void> updateFeedMetadata({
    required int feedId,
    required String title,
    String? siteUrl,
    String? iconUrl,
    String? description,
    required DateTime fetchedAt,
  }) async {
    final db = await _db;
    await db.update(
      'feeds',
      {
        'title': title,
        'site_url': siteUrl,
        'description': description,
        'last_fetched_at': fetchedAt.millisecondsSinceEpoch,
        // Left out rather than written as null: a lookup that came back empty
        // this time must not erase the icon an earlier one found.
        'icon_url': ?iconUrl,
      },
      where: 'id = ?',
      whereArgs: [feedId],
    );
  }

  Future<void> deleteFeed(int feedId) async {
    final db = await _db;
    await db.delete('feeds', where: 'id = ?', whereArgs: [feedId]);
  }

  // --- Articles -------------------------------------------------------------

  /// Stores [records] and returns how many of them were new.
  ///
  /// An article that already exists under the same guid has its content
  /// refreshed while its read and starred flags are left untouched.
  Future<int> upsertArticles(
    int feedId,
    List<ArticleRecord> records, {
    required DateTime fetchedAt,
  }) async {
    if (records.isEmpty) return 0;

    final db = await _db;
    var inserted = 0;

    await db.transaction((txn) async {
      for (final record in records) {
        final existing = await txn.query(
          'articles',
          columns: ['id'],
          where: 'feed_id = ? AND guid = ?',
          whereArgs: [feedId, record.guid],
          limit: 1,
        );

        if (existing.isEmpty) {
          await txn.insert('articles', {
            'feed_id': feedId,
            'guid': record.guid,
            'title': record.title,
            'link': record.link,
            'author': record.author,
            'summary': record.summary,
            'content': record.content,
            'published_at': record.publishedAt?.millisecondsSinceEpoch,
            'fetched_at': fetchedAt.millisecondsSinceEpoch,
          });
          inserted++;
        } else {
          // Read and starred flags belong to the user, not to the feed.
          await txn.update(
            'articles',
            {
              'title': record.title,
              'link': record.link,
              'author': record.author,
              'summary': record.summary,
              'content': record.content,
              'published_at': record.publishedAt?.millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
        }
      }
    });

    return inserted;
  }

  /// Covers every feed when [feedId] is null.
  Future<List<Article>> listArticles({
    int? feedId,
    ArticleFilter filter = ArticleFilter.all,
    int limit = 200,
    int offset = 0,
  }) async {
    final db = await _db;

    final conditions = <String>[];
    final args = <Object?>[];

    if (feedId != null) {
      conditions.add('a.feed_id = ?');
      args.add(feedId);
    }
    switch (filter) {
      case ArticleFilter.unread:
        conditions.add('a.is_read = 0');
      case ArticleFilter.starred:
        conditions.add('a.is_starred = 1');
      case ArticleFilter.all:
        break;
    }

    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final rows = await db.rawQuery(
      '''
      SELECT a.*, f.title AS feed_title
      FROM articles a
      INNER JOIN feeds f ON f.id = a.feed_id
      $where
      ORDER BY COALESCE(a.published_at, a.fetched_at) DESC, a.id DESC
      LIMIT ? OFFSET ?
    ''',
      [...args, limit, offset],
    );

    return rows.map(_articleFromRow).toList();
  }

  Future<Article?> findArticle(int articleId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT a.*, f.title AS feed_title
      FROM articles a
      INNER JOIN feeds f ON f.id = a.feed_id
      WHERE a.id = ?
      ''',
      [articleId],
    );
    return rows.isEmpty ? null : _articleFromRow(rows.first);
  }

  Future<void> setRead(int articleId, bool isRead) async {
    final db = await _db;
    await db.update(
      'articles',
      {'is_read': isRead ? 1 : 0},
      where: 'id = ?',
      whereArgs: [articleId],
    );
  }

  Future<void> setStarred(int articleId, bool isStarred) async {
    final db = await _db;
    await db.update(
      'articles',
      {'is_starred': isStarred ? 1 : 0},
      where: 'id = ?',
      whereArgs: [articleId],
    );
  }

  /// Covers every feed when [feedId] is null.
  Future<void> markAllRead({int? feedId}) async {
    final db = await _db;
    await db.update(
      'articles',
      {'is_read': 1},
      where: feedId == null ? 'is_read = 0' : 'feed_id = ? AND is_read = 0',
      whereArgs: feedId == null ? null : [feedId],
    );
  }

  Future<int> unreadCount() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM articles WHERE is_read = 0',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  // --- Rows <-> models ------------------------------------------------------

  Feed _feedFromRow(Map<String, Object?> row) {
    return Feed(
      id: row['id']! as int,
      title: row['title']! as String,
      feedUrl: row['feed_url']! as String,
      siteUrl: row['site_url'] as String?,
      iconUrl: row['icon_url'] as String?,
      description: row['description'] as String?,
      lastFetchedAt: _dateFromMillis(row['last_fetched_at']),
      unreadCount: (row['unread_count'] as int?) ?? 0,
      totalCount: (row['total_count'] as int?) ?? 0,
    );
  }

  Article _articleFromRow(Map<String, Object?> row) {
    return Article(
      id: row['id']! as int,
      feedId: row['feed_id']! as int,
      guid: row['guid']! as String,
      title: row['title']! as String,
      feedTitle: row['feed_title'] as String?,
      link: row['link'] as String?,
      author: row['author'] as String?,
      summary: row['summary'] as String?,
      content: row['content'] as String?,
      publishedAt: _dateFromMillis(row['published_at']),
      fetchedAt: _dateFromMillis(row['fetched_at'])!,
      isRead: (row['is_read'] as int? ?? 0) == 1,
      isStarred: (row['is_starred'] as int? ?? 0) == 1,
    );
  }

  DateTime? _dateFromMillis(Object? value) {
    if (value is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
  }
}

class ArticleRecord {
  const ArticleRecord({
    required this.guid,
    required this.title,
    this.link,
    this.author,
    this.summary,
    this.content,
    this.publishedAt,
  });

  final String guid;
  final String title;
  final String? link;
  final String? author;
  final String? summary;
  final String? content;
  final DateTime? publishedAt;
}
