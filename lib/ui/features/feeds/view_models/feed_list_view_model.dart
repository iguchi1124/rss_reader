import '../../../../data/repositories/feed_repository.dart';
import '../../../../domain/models/feed.dart';
import '../../../../utils/result.dart';
import '../../../core/disposable_view_model.dart';

class FeedListViewModel extends DisposableViewModel {
  FeedListViewModel({required FeedRepository repository})
    : _repository = repository {
    // Unread counts also change from other screens, e.g. marking an article
    // read, so this follows the repository rather than only its own actions.
    _repository.addListener(_onRepositoryChanged);
    load();
  }

  final FeedRepository _repository;

  List<Feed> _feeds = const [];
  List<Feed> get feeds => List.unmodifiable(_feeds);

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isEmpty => !_isLoading && _feeds.isEmpty;

  int get totalUnread => _feeds.fold(0, (sum, feed) => sum + feed.unreadCount);

  Future<void> load() async {
    _errorMessage = null;
    try {
      _feeds = await _repository.listFeeds();
    } on Object catch (error) {
      _errorMessage = 'Could not load feeds: $error';
    } finally {
      _isLoading = false;
      safeNotifyListeners();
    }
  }

  /// Returns null on success, or a message explaining the failure.
  Future<String?> addFeed(String url) async {
    final result = await _repository.addFeed(url);
    return switch (result) {
      Ok() => null,
      Failure(:final error) =>
        error is FeedException ? error.message : 'Could not add the feed.',
    };
  }

  Future<void> deleteFeed(Feed feed) => _repository.deleteFeed(feed.id);

  /// Returns a summary to show the user.
  Future<String> refreshAll() async {
    if (_isRefreshing) return 'Already refreshing.';

    _isRefreshing = true;
    safeNotifyListeners();
    try {
      final summary = await _repository.refreshAll();
      return summary.message;
    } finally {
      _isRefreshing = false;
      safeNotifyListeners();
    }
  }

  Future<void> markAllRead(Feed feed) =>
      _repository.markAllRead(feedId: feed.id);

  void _onRepositoryChanged() => load();

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}
