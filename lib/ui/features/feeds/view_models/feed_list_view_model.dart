import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/providers.dart';
import '../../../../domain/models/feed.dart';
import '../../../../utils/result.dart';
import '../../../core/refresh_state.dart';

final feedListProvider = AsyncNotifierProvider<FeedListViewModel, List<Feed>>(
  FeedListViewModel.new,
);

final feedListRefreshingProvider = NotifierProvider<RefreshState, bool>(
  RefreshState.new,
);

/// Unread articles across every feed, for the badge in the navigation bar.
final unreadCountProvider = Provider<int>((ref) {
  final feeds = ref.watch(feedListProvider).value ?? const <Feed>[];
  return feeds.fold(0, (sum, feed) => sum + feed.unreadCount);
});

class FeedListViewModel extends AsyncNotifier<List<Feed>> {
  @override
  Future<List<Feed>> build() {
    ref.watch(feedRevisionProvider);
    return ref.watch(feedRepositoryProvider).listFeeds();
  }

  /// Returns null on success, or a message explaining the failure.
  Future<String?> addFeed(String url) async {
    final result = await ref.writeFeedData(
      (repository) => repository.addFeed(url),
    );
    return switch (result) {
      Ok() => null,
      Failure(:final error) =>
        error is FeedException ? error.message : 'Could not add the feed.',
    };
  }

  Future<void> deleteFeed(Feed feed) =>
      ref.writeFeedData((repository) => repository.deleteFeed(feed.id));

  /// Returns a summary to show the user.
  Future<String> refreshAll() async {
    final refreshing = ref.read(feedListRefreshingProvider.notifier);
    if (!refreshing.start()) return 'Already refreshing.';

    try {
      return await ref.writeFeedData(
        (repository) async => (await repository.refreshAll()).message,
      );
    } finally {
      refreshing.finish();
    }
  }

  Future<void> markAllRead(Feed feed) => ref.writeFeedData(
    (repository) => repository.markAllRead(feedId: feed.id),
  );
}
