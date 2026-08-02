import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/feed_repository.dart';
import 'services/feed_api_client.dart';
import 'services/feed_database.dart';

final feedApiClientProvider = Provider<FeedApiClient>((ref) {
  final client = FeedApiClient();
  ref.onDispose(client.dispose);
  return client;
});

final feedDatabaseProvider = Provider<FeedDatabase>((ref) {
  final database = FeedDatabase();
  ref.onDispose(database.close);
  return database;
});

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(
    apiClient: ref.watch(feedApiClientProvider),
    database: ref.watch(feedDatabaseProvider),
  );
});

/// Counter bumped after every write, watched by everything that reads feeds or
/// articles.
///
/// A write on one screen changes what another shows — marking an article read
/// moves the unread badge, deleting a feed empties the article list — and the
/// writer cannot know which readers are affected. One shared signal reloads
/// them all.
final feedRevisionProvider = NotifierProvider<FeedRevision, int>(
  FeedRevision.new,
);

class FeedRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

extension FeedDataWrites on Ref {
  /// Runs [write] against the repository, then reloads every provider that
  /// reads stored feeds or articles.
  ///
  /// Both handles are taken before [write] is awaited. An auto-disposing
  /// provider can be gone by the time its write finishes — the user popped the
  /// screen — and its [Ref] is unusable from then on, but the change still has
  /// to reach the screens that stayed.
  Future<T> writeFeedData<T>(
    Future<T> Function(FeedRepository repository) write,
  ) {
    final repository = read(feedRepositoryProvider);
    final revision = read(feedRevisionProvider.notifier);
    return write(repository).whenComplete(revision.bump);
  }
}
