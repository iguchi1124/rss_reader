import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/article.dart';
import '../../../../domain/models/feed.dart';
import '../../../core/app_messenger.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_header_scaffold.dart';
import '../../../core/widgets/status_view.dart';
import '../../article_detail/views/article_detail_screen.dart';
import '../view_models/article_list_view_model.dart';
import 'article_tile.dart';

/// Shows articles from [feed], or from every feed when it is null.
class ArticleListScreen extends ConsumerWidget {
  const ArticleListScreen({super.key, this.feed});

  final Feed? feed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncArticles = ref.watch(articleListProvider(feed));
    final isRefreshing = ref.watch(articleListRefreshingProvider(feed));
    final filter = ref.watch(articleFilterProvider(feed));

    return GlassHeaderScaffold(
      title: Text(_title),
      actions: [
        IconButton(
          onPressed: isRefreshing ? null : () => _refresh(context, ref),
          icon: isRefreshing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
        IconButton(
          onPressed: (asyncArticles.value?.isEmpty ?? true)
              ? null
              : () => _markAllRead(context, ref),
          icon: const Icon(Icons.done_all),
          tooltip: 'Mark all as read',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: _FilterBar(
          filter: filter,
          onChanged: ref.read(articleFilterProvider(feed).notifier).select,
        ),
      ),
      body: (context) => RefreshIndicator(
        // The list runs behind the header now, so the spinner is pushed clear
        // of it rather than turning underneath the glass.
        edgeOffset: MediaQuery.paddingOf(context).top,
        onRefresh: () => _refresh(context, ref),
        child: _buildBody(context, ref, asyncArticles, filter),
      ),
    );
  }

  String get _title => feed?.title ?? 'Latest';

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Article>> asyncArticles,
    ArticleFilter filter,
  ) {
    if (asyncArticles.error case final error?) {
      return ErrorView(
        message: 'Could not load articles: $error',
        onRetry: () => ref.invalidate(articleListProvider(feed)),
      );
    }

    final articles = asyncArticles.value;
    if (articles == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (articles.isEmpty) {
      final chrome = MediaQuery.paddingOf(context);

      // Stays scrollable while empty so RefreshIndicator still triggers. The
      // padding is taken out of the minimum height as well as added around the
      // child, so the view centres in the space between the header and the tab
      // bar rather than behind them.
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: chrome.top, bottom: chrome.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - chrome.top - chrome.bottom)
                  .clamp(0.0, double.infinity),
            ),
            child: EmptyView(
              icon: switch (filter) {
                ArticleFilter.starred => Icons.star_border,
                ArticleFilter.unread => Icons.mark_email_read_outlined,
                ArticleFilter.all => Icons.article_outlined,
              },
              title: switch (filter) {
                ArticleFilter.starred => 'No starred articles',
                ArticleFilter.unread => 'No unread articles',
                ArticleFilter.all => 'No articles yet',
              },
              message: filter == ArticleFilter.all
                  ? 'Pull to refresh, or add a feed to get started.'
                  : null,
            ),
          ),
        ),
      );
    }

    final viewModel = ref.read(articleListProvider(feed).notifier);

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      // Top and bottom are both set explicitly rather than left to the
      // automatic MediaQuery padding, because what they clear is the glass
      // header and the floating tab bar — widgets of ours, not system insets.
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top,
        right: rightGutter(context),
        bottom: MediaQuery.paddingOf(context).bottom,
      ),
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
            showFeedTitle: feed == null,
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

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final messenger = AppMessenger.of(context);
    final message = await ref
        .read(articleListProvider(feed).notifier)
        .refresh();
    messenger.show(message);
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark all as read'),
        content: Text(
          feed == null
              ? 'Every article will be marked as read.'
              : 'Every article in "$_title" will be marked as read.',
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

    if (confirmed ?? false) {
      await ref.read(articleListProvider(feed).notifier).markAllRead();
    }
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
      color: theme.colorScheme.primary,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRead ? Icons.mark_email_unread_outlined : Icons.drafts_outlined,
            color: theme.colorScheme.onPrimary,
          ),
          const SizedBox(width: 8),
          Text(
            isRead ? 'Mark unread' : 'Mark read',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
