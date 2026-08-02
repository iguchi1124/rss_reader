import '../../../../data/repositories/feed_repository.dart';
import '../../../../domain/models/article.dart';
import '../../../../domain/models/feed.dart';
import '../../../../utils/result.dart';
import '../../../core/disposable_view_model.dart';

/// Scoped to [feed] when one is given, otherwise spanning every feed.
class ArticleListViewModel extends DisposableViewModel {
  ArticleListViewModel({required FeedRepository repository, this.feed})
    : _repository = repository {
    _repository.addListener(_onRepositoryChanged);
    load();
  }

  final FeedRepository _repository;

  /// Null when showing articles from every feed.
  final Feed? feed;

  List<Article> _articles = const [];
  List<Article> get articles => List.unmodifiable(_articles);

  ArticleFilter _filter = ArticleFilter.all;
  ArticleFilter get filter => _filter;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isEmpty => !_isLoading && _articles.isEmpty;

  String get title => feed?.title ?? 'Latest';

  Future<void> load() async {
    _errorMessage = null;
    try {
      _articles = await _repository.listArticles(
        feedId: feed?.id,
        filter: _filter,
      );
    } on Object catch (error) {
      _errorMessage = 'Could not load articles: $error';
    } finally {
      _isLoading = false;
      safeNotifyListeners();
    }
  }

  Future<void> setFilter(ArticleFilter filter) async {
    if (_filter == filter) return;
    _filter = filter;
    safeNotifyListeners();
    await load();
  }

  /// Returns a summary to show the user.
  Future<String> refresh() async {
    if (_isRefreshing) return 'Already refreshing.';

    _isRefreshing = true;
    safeNotifyListeners();
    try {
      final target = feed;
      if (target == null) {
        return (await _repository.refreshAll()).message;
      }

      final result = await _repository.refreshFeed(target);
      return switch (result) {
        Ok(:final value) => switch (value) {
          0 => 'No new articles',
          1 => '1 new article',
          _ => '$value new articles',
        },
        Failure(:final error) =>
          error is FeedException ? error.message : 'Refresh failed.',
      };
    } finally {
      _isRefreshing = false;
      safeNotifyListeners();
    }
  }

  Future<void> toggleRead(Article article) =>
      _repository.setRead(article.id, !article.isRead);

  Future<void> toggleStarred(Article article) =>
      _repository.setStarred(article.id, !article.isStarred);

  Future<void> markAllRead() => _repository.markAllRead(feedId: feed?.id);

  void _onRepositoryChanged() => load();

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}
