import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/feed.dart';
import '../../../../utils/date_format.dart';
import '../../../core/widgets/status_view.dart';
import '../../articles/views/article_list_screen.dart';
import '../view_models/feed_list_view_model.dart';
import 'add_feed_dialog.dart';

class FeedListScreen extends StatelessWidget {
  const FeedListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FeedListViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feeds'),
        actions: [
          IconButton(
            onPressed: viewModel.isRefreshing || viewModel.feeds.isEmpty
                ? null
                : () => _refreshAll(context, viewModel),
            icon: viewModel.isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh all',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, viewModel),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshAll(context, viewModel),
        child: _buildBody(context, viewModel),
      ),
    );
  }

  Widget _buildBody(BuildContext context, FeedListViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.errorMessage case final message?) {
      return ErrorView(message: message, onRetry: viewModel.load);
    }

    if (viewModel.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: EmptyView(
              icon: Icons.rss_feed,
              title: 'No feeds yet',
              message: 'Add the URL of a site or feed you want to follow.',
              action: FilledButton.icon(
                onPressed: () => _showAddDialog(context, viewModel),
                icon: const Icon(Icons.add),
                label: const Text('Add feed'),
              ),
            ),
          ),
        ),
      );
    }

    final feeds = viewModel.feeds;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      // Bottom padding keeps the FAB from covering the last row.
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: feeds.length,
      separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
      itemBuilder: (context, index) =>
          _FeedTile(feed: feeds[index], viewModel: viewModel),
    );
  }

  Future<void> _showAddDialog(
    BuildContext context,
    FeedListViewModel viewModel,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AddFeedDialog(onSubmit: viewModel.addFeed),
    );

    if (added ?? false) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Feed added.')));
    }
  }

  Future<void> _refreshAll(
    BuildContext context,
    FeedListViewModel viewModel,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await viewModel.refreshAll();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FeedTile extends StatelessWidget {
  const _FeedTile({required this.feed, required this.viewModel});

  final Feed feed;
  final FeedListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          // Feeds have no icon of their own, so the initial stands in for one.
          feed.title.characters.firstOrNull?.toUpperCase() ?? '?',
          style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
        ),
      ),
      title: Text(
        feed.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        feed.lastFetchedAt == null
            ? 'Never refreshed'
            : 'Updated ${formatRelativeDate(feed.lastFetchedAt!)} · ${feed.totalCount} articles',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (feed.unreadCount > 0)
            Badge(
              label: Text('${feed.unreadCount}'),
              backgroundColor: theme.colorScheme.primary,
            ),
          PopupMenuButton<_FeedAction>(
            onSelected: (action) => _onAction(context, action),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _FeedAction.markAllRead,
                child: ListTile(
                  leading: Icon(Icons.done_all),
                  title: Text('Mark all as read'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _FeedAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Unsubscribe'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ArticleListScreen(feed: feed)),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, _FeedAction action) async {
    switch (action) {
      case _FeedAction.markAllRead:
        await viewModel.markAllRead(feed);
      case _FeedAction.delete:
        await _confirmDelete(context);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsubscribe'),
        content: Text(
          'Unsubscribing from "${feed.title}" also deletes its saved articles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unsubscribe'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) await viewModel.deleteFeed(feed);
  }
}

enum _FeedAction { markAllRead, delete }
