import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/feed_repository.dart';
import '../../../../domain/models/article.dart';
import '../../../../domain/models/feed.dart';
import '../../../core/widgets/status_view.dart';
import '../../article_detail/views/article_detail_screen.dart';
import '../view_models/article_list_view_model.dart';
import 'article_tile.dart';

/// Shows articles from [feed], or from every feed when it is null.
class ArticleListScreen extends StatelessWidget {
  const ArticleListScreen({super.key, this.feed});

  final Feed? feed;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // Gives each feed its own view model instead of reusing one across feeds.
      key: ValueKey(feed?.id),
      create: (context) => ArticleListViewModel(
        repository: context.read<FeedRepository>(),
        feed: feed,
      ),
      child: const _ArticleListView(),
    );
  }
}

class _ArticleListView extends StatelessWidget {
  const _ArticleListView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ArticleListViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(viewModel.title),
        actions: [
          IconButton(
            onPressed: viewModel.isRefreshing
                ? null
                : () => _refresh(context, viewModel),
            icon: viewModel.isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: viewModel.articles.isEmpty
                ? null
                : () => _markAllRead(context, viewModel),
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _FilterBar(
            filter: viewModel.filter,
            onChanged: viewModel.setFilter,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(context, viewModel),
        child: _buildBody(context, viewModel),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ArticleListViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.errorMessage case final message?) {
      return ErrorView(message: message, onRetry: viewModel.load);
    }

    if (viewModel.isEmpty) {
      // Stays scrollable while empty so RefreshIndicator still triggers.
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: EmptyView(
              icon: switch (viewModel.filter) {
                ArticleFilter.starred => Icons.star_border,
                ArticleFilter.unread => Icons.mark_email_read_outlined,
                ArticleFilter.all => Icons.article_outlined,
              },
              title: switch (viewModel.filter) {
                ArticleFilter.starred => 'No starred articles',
                ArticleFilter.unread => 'No unread articles',
                ArticleFilter.all => 'No articles yet',
              },
              message: viewModel.filter == ArticleFilter.all
                  ? 'Pull to refresh, or add a feed to get started.'
                  : null,
            ),
          ),
        ),
      );
    }

    final articles = viewModel.articles;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: articles.length,
      separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final article = articles[index];
        return Dismissible(
          key: ValueKey(article.id),
          direction: DismissDirection.startToEnd,
          // The swipe toggles read state rather than removing the row, so the
          // dismissal is always rejected.
          confirmDismiss: (_) async {
            await viewModel.toggleRead(article);
            return false;
          },
          background: _ReadSwipeBackground(isRead: article.isRead),
          child: ArticleTile(
            article: article,
            showFeedTitle: viewModel.feed == null,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ArticleDetailScreen(article: article),
              ),
            ),
            onToggleStarred: () => viewModel.toggleStarred(article),
          ),
        );
      },
    );
  }

  Future<void> _refresh(
    BuildContext context,
    ArticleListViewModel viewModel,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await viewModel.refresh();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _markAllRead(
    BuildContext context,
    ArticleListViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark all as read'),
        content: Text(
          viewModel.feed == null
              ? 'Every article will be marked as read.'
              : 'Every article in "${viewModel.title}" will be marked as read.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Mark read'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) await viewModel.markAllRead();
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.onChanged});

  final ArticleFilter filter;
  final ValueChanged<ArticleFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<ArticleFilter>(
          segments: [
            for (final value in ArticleFilter.values)
              ButtonSegment(value: value, label: Text(value.label)),
          ],
          selected: {filter},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ),
    );
  }
}

class _ReadSwipeBackground extends StatelessWidget {
  const _ReadSwipeBackground({required this.isRead});

  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.primaryContainer,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRead ? Icons.mark_email_unread_outlined : Icons.drafts_outlined,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            isRead ? 'Mark unread' : 'Mark read',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
