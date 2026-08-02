import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/providers.dart';
import '../../../../data/repositories/feed_repository.dart';
import '../../../../domain/models/article.dart';
import '../../../../domain/models/feed.dart';
import '../../../../utils/result.dart';
import '../../../core/refresh_state.dart';

/// Keyed by the feed being shown, or null for articles from every feed.
///
/// Auto-disposing gives a pushed feed the same lifetime its view model used to
/// have: the filter resets the next time that feed is opened.
final articleListProvider =
    AsyncNotifierProvider.family<ArticleListViewModel, List<Article>, Feed?>(
      ArticleListViewModel.new,
      isAutoDispose: true,
    );

final articleFilterProvider =
    NotifierProvider.family<ArticleFilterNotifier, ArticleFilter, Feed?>(
      (_) => ArticleFilterNotifier(),
      isAutoDispose: true,
    );

final articleListRefreshingProvider =
    NotifierProvider.family<RefreshState, bool, Feed?>(
      (_) => RefreshState(),
      isAutoDispose: true,
    );

class ArticleFilterNotifier extends Notifier<ArticleFilter> {
  @override
  ArticleFilter build() => ArticleFilter.all;

  void select(ArticleFilter filter) => state = filter;
}

class ArticleListViewModel extends AsyncNotifier<List<Article>> {
  ArticleListViewModel(this.feed);

  /// Null when showing articles from every feed.
  final Feed? feed;

  @override
  Future<List<Article>> build() {
    ref.watch(feedRevisionProvider);
    return ref
        .watch(feedRepositoryProvider)
        .listArticles(
          feedId: feed?.id,
          filter: ref.watch(articleFilterProvider(feed)),
        );
  }

  /// Returns a summary to show the user.
  Future<String> refresh() async {
    final refreshing = ref.read(articleListRefreshingProvider(feed).notifier);
    if (!refreshing.start()) return 'Already refreshing.';

    try {
      return await ref.writeFeedData(_refreshWith);
    } finally {
      // Popping the screen during a refresh disposes the flag along with the
      // rest of this feed's state, leaving nothing to reset.
      if (ref.mounted) refreshing.finish();
    }
  }

  Future<String> _refreshWith(FeedRepository repository) async {
    final target = feed;
    if (target == null) return (await repository.refreshAll()).message;

    final result = await repository.refreshFeed(target);
    return switch (result) {
      Ok(:final value) => switch (value) {
        0 => 'No new articles',
        1 => '1 new article',
        _ => '$value new articles',
      },
      Failure(:final error) =>
        error is FeedException ? error.message : 'Refresh failed.',
    };
  }

  Future<void> toggleRead(Article article) => ref.writeFeedData(
    (repository) => repository.setRead(article.id, !article.isRead),
  );

  Future<void> toggleStarred(Article article) => ref.writeFeedData(
    (repository) => repository.setStarred(article.id, !article.isStarred),
  );

  Future<void> markAllRead() => ref.writeFeedData(
    (repository) => repository.markAllRead(feedId: feed?.id),
  );
}
