import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/feed.dart';
import '../../../../utils/date_format.dart';
import '../../../core/app_messenger.dart';
import '../../../core/widgets/status_view.dart';
import '../../articles/views/article_list_screen.dart';
import '../view_models/feed_list_view_model.dart';
import 'add_feed_dialog.dart';

class FeedListScreen extends ConsumerWidget {
  const FeedListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFeeds = ref.watch(feedListProvider);
    final isRefreshing = ref.watch(feedListRefreshingProvider);
    final hasFeeds = asyncFeeds.value?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feeds'),
        actions: [
          IconButton(
            onPressed: isRefreshing || !hasFeeds
                ? null
                : () => _refreshAll(context, ref),
            icon: isRefreshing
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
      // This screen's Scaffold has no bottom bar of its own to lift the FAB
      // over: the tab bar belongs to HomeScreen's Scaffold, and `extendBody`
      // there runs this one to the bottom of the window. Nothing but the
      // padding keeps the two apart.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshAll(context, ref),
        child: _buildBody(context, ref, asyncFeeds),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Feed>> asyncFeeds,
  ) {
    if (asyncFeeds.error case final error?) {
      return ErrorView(
        message: 'Could not load feeds: $error',
        onRetry: () => ref.invalidate(feedListProvider),
      );
    }

    final feeds = asyncFeeds.value;
    if (feeds == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (feeds.isEmpty) {
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
                onPressed: () => _showAddDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add feed'),
              ),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      // Clears the FAB, and on phones the floating tab bar beneath it.
      padding: EdgeInsets.only(
        bottom: 88 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: feeds.length,
      separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
      itemBuilder: (context, index) => _FeedTile(feed: feeds[index]),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final messenger = AppMessenger.of(context);

    final added = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AddFeedDialog(onSubmit: ref.read(feedListProvider.notifier).addFeed),
    );

    if (added ?? false) {
      messenger.show('Feed added.');
    }
  }

  Future<void> _refreshAll(BuildContext context, WidgetRef ref) async {
    final messenger = AppMessenger.of(context);
    final message = await ref.read(feedListProvider.notifier).refreshAll();
    messenger.show(message);
  }
}

class _FeedTile extends ConsumerWidget {
  const _FeedTile({required this.feed});

  final Feed feed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            onSelected: (action) => _onAction(context, ref, action),
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

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _FeedAction action,
  ) async {
    switch (action) {
      case _FeedAction.markAllRead:
        await ref.read(feedListProvider.notifier).markAllRead(feed);
      case _FeedAction.delete:
        await _confirmDelete(context, ref);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
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

    if (confirmed ?? false) {
      await ref.read(feedListProvider.notifier).deleteFeed(feed);
    }
  }
}

enum _FeedAction { markAllRead, delete }
