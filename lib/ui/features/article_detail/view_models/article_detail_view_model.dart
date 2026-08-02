import '../../../../data/repositories/feed_repository.dart';
import '../../../../domain/models/article.dart';
import '../../../core/disposable_view_model.dart';

/// Opening the article marks it read, once per visit: leaving before finishing
/// should not undo that.
class ArticleDetailViewModel extends DisposableViewModel {
  ArticleDetailViewModel({
    required FeedRepository repository,
    required Article article,
  }) : _repository = repository,
       _article = article {
    _repository.addListener(_onRepositoryChanged);
    _markAsRead();
  }

  final FeedRepository _repository;

  Article _article;
  Article get article => _article;

  Future<void> toggleStarred() =>
      _repository.setStarred(_article.id, !_article.isStarred);

  Future<void> markAsUnread() async {
    await _repository.setRead(_article.id, false);
  }

  Future<void> _markAsRead() async {
    if (_article.isRead) return;
    await _repository.setRead(_article.id, true);
  }

  Future<void> _onRepositoryChanged() async {
    final updated = await _repository.findArticle(_article.id);
    // The article is gone once its feed is deleted; keep showing what the user
    // was reading.
    if (updated == null) return;

    _article = updated;
    safeNotifyListeners();
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}
