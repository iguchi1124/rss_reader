import '../../domain/models/article.dart';
import '../../domain/models/feed.dart';
import '../../utils/result.dart';
import '../models/parsed_feed.dart';
import '../services/feed_api_client.dart';
import '../services/feed_database.dart';
import '../services/feed_parser.dart';

/// The single source of truth for subscribed feeds and their articles.
///
/// Combines fetching (HTTP), parsing (XML), and storage (SQLite), and exposes
/// domain models only. Holds no state of its own; announcing a write so other
/// screens catch up is the callers' job.
class FeedRepository {
  FeedRepository({
    required FeedApiClient apiClient,
    required FeedDatabase database,
    FeedParser parser = const FeedParser(),
  }) : _apiClient = apiClient,
       _database = database,
       _parser = parser;

  final FeedApiClient _apiClient;
  final FeedDatabase _database;
  final FeedParser _parser;

  // --- Queries --------------------------------------------------------------

  Future<List<Feed>> listFeeds() => _database.listFeeds();

  Future<List<Article>> listArticles({
    int? feedId,
    ArticleFilter filter = ArticleFilter.all,
    int limit = 200,
    int offset = 0,
  }) => _database.listArticles(
    feedId: feedId,
    filter: filter,
    limit: limit,
    offset: offset,
  );

  Future<Article?> findArticle(int articleId) =>
      _database.findArticle(articleId);

  Future<int> unreadCount() => _database.unreadCount();

  // --- Subscriptions --------------------------------------------------------

  /// When [url] turns out to be a site rather than a feed, its HTML is searched
  /// for a feed link and that URL is subscribed to instead.
  Future<Result<Feed>> addFeed(String url) async {
    final normalized = _normalizeUrl(url);
    if (normalized == null) {
      return const Failure(FeedException('That URL is not valid.'));
    }

    final resolved = await _resolveFeed(normalized);
    switch (resolved) {
      case Failure(:final error, :final stackTrace):
        return Failure(error, stackTrace);
      case Ok(value: (final feedUrl, final parsed)):
        final existing = await _database.findFeedByUrl(feedUrl);
        if (existing != null) {
          return const Failure(
            FeedException('You already subscribe to this feed.'),
          );
        }

        final fetchedAt = DateTime.now();
        final feedId = await _database.insertFeed(
          title: parsed.title,
          feedUrl: feedUrl,
          siteUrl: parsed.siteUrl,
          description: parsed.description,
        );
        await _saveItems(feedId, parsed, fetchedAt: fetchedAt);

        final feeds = await _database.listFeeds();
        return Ok(feeds.firstWhere((feed) => feed.id == feedId));
    }
  }

  Future<void> deleteFeed(int feedId) => _database.deleteFeed(feedId);

  // --- Refresh --------------------------------------------------------------

  /// Re-fetches one feed and returns how many articles were new.
  Future<Result<int>> refreshFeed(Feed feed) async {
    final response = await _apiClient.fetch(feed.feedUrl);
    switch (response) {
      case Failure(:final error, :final stackTrace):
        return Failure(error, stackTrace);
      case Ok(value: final body):
        final parsed = _parser.parse(body, feedUrl: feed.feedUrl);
        switch (parsed) {
          case Failure(:final error, :final stackTrace):
            return Failure(error, stackTrace);
          case Ok(value: final document):
            final fetchedAt = DateTime.now();
            await _database.updateFeedMetadata(
              feedId: feed.id,
              title: document.title,
              siteUrl: document.siteUrl,
              description: document.description,
              fetchedAt: fetchedAt,
            );
            final added = await _saveItems(
              feed.id,
              document,
              fetchedAt: fetchedAt,
            );
            return Ok(added);
        }
    }
  }

  /// Refreshes every feed.
  ///
  /// A failing feed does not stop the others; its title is reported back in the
  /// summary instead.
  Future<RefreshSummary> refreshAll() async {
    final feeds = await _database.listFeeds();
    var added = 0;
    final failures = <String>[];

    for (final feed in feeds) {
      final result = await refreshFeed(feed);
      switch (result) {
        case Ok(:final value):
          added += value;
        case Failure():
          failures.add(feed.title);
      }
    }

    return RefreshSummary(
      newArticles: added,
      failedFeeds: failures,
      refreshedFeeds: feeds.length,
    );
  }

  // --- Article state --------------------------------------------------------

  Future<void> setRead(int articleId, bool isRead) =>
      _database.setRead(articleId, isRead);

  Future<void> setStarred(int articleId, bool isStarred) =>
      _database.setStarred(articleId, isStarred);

  Future<void> markAllRead({int? feedId}) =>
      _database.markAllRead(feedId: feedId);

  // --- Internals ------------------------------------------------------------

  /// Locates the feed document behind [url].
  ///
  /// If the response does not parse as a feed it is treated as HTML and
  /// `<link rel="alternate">` is followed. Returns the URL that was settled on
  /// alongside the parsed feed.
  Future<Result<(String, ParsedFeed)>> _resolveFeed(String url) async {
    final response = await _apiClient.fetch(url);
    switch (response) {
      case Failure(:final error, :final stackTrace):
        return Failure(error, stackTrace);
      case Ok(value: final body):
        final parsed = _parser.parse(body, feedUrl: url);
        if (parsed case Ok(:final value)) return Ok((url, value));
        final parseFailure = parsed as Failure<ParsedFeed>;

        final discovered = _apiClient.discoverFeedUrl(body, baseUrl: url);
        if (discovered == null || discovered == url) {
          // The original parse error describes the problem better than a
          // "no feed found" message would.
          return Failure(parseFailure.error, parseFailure.stackTrace);
        }

        final retry = await _apiClient.fetch(discovered);
        switch (retry) {
          case Failure(:final error, :final stackTrace):
            return Failure(error, stackTrace);
          case Ok(value: final feedBody):
            final feedParsed = _parser.parse(feedBody, feedUrl: discovered);
            return switch (feedParsed) {
              Ok(:final value) => Ok((discovered, value)),
              Failure(:final error, :final stackTrace) => Failure(
                error,
                stackTrace,
              ),
            };
        }
    }
  }

  Future<int> _saveItems(
    int feedId,
    ParsedFeed parsed, {
    required DateTime fetchedAt,
  }) {
    final records = parsed.items
        .where((item) => item.guid.isNotEmpty)
        .map(
          (item) => ArticleRecord(
            guid: item.guid,
            title: item.title,
            link: item.link,
            author: item.author,
            summary: item.summary,
            content: item.content,
            publishedAt: item.publishedAt,
          ),
        )
        .toList();

    return _database.upsertArticles(feedId, records, fetchedAt: fetchedAt);
  }

  /// Cleans up user input, defaulting a missing scheme to https.
  String? _normalizeUrl(String input) {
    var value = input.trim();
    if (value.isEmpty) return null;

    if (!value.contains('://')) value = 'https://$value';

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasAuthority) return null;
    return uri.toString();
  }
}

class RefreshSummary {
  const RefreshSummary({
    required this.newArticles,
    required this.failedFeeds,
    required this.refreshedFeeds,
  });

  final int newArticles;
  final List<String> failedFeeds;
  final int refreshedFeeds;

  /// One-line summary shown to the user.
  String get message {
    if (refreshedFeeds == 0) return 'No feeds yet.';

    final base = switch (newArticles) {
      0 => 'No new articles',
      1 => '1 new article',
      _ => '$newArticles new articles',
    };
    if (failedFeeds.isEmpty) return base;
    return '$base (${failedFeeds.length} feed(s) failed to update)';
  }
}
