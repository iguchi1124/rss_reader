import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/providers.dart';
import '../../../../domain/models/article.dart';

/// Null once the article's feed is deleted; the screen keeps showing the copy it
/// was opened with in that case.
final articleProvider =
    AsyncNotifierProvider.family<ArticleDetailViewModel, Article?, int>(
      ArticleDetailViewModel.new,
      isAutoDispose: true,
    );

class ArticleDetailViewModel extends AsyncNotifier<Article?> {
  ArticleDetailViewModel(this.articleId);

  final int articleId;

  @override
  Future<Article?> build() {
    ref.watch(feedRevisionProvider);
    return ref.watch(feedRepositoryProvider).findArticle(articleId);
  }

  Future<void> setRead(bool isRead) =>
      ref.writeFeedData((repository) => repository.setRead(articleId, isRead));

  Future<void> toggleStarred(Article article) => ref.writeFeedData(
    (repository) => repository.setStarred(articleId, !article.isStarred),
  );
}
