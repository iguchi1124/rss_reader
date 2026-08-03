import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/feed.dart';
import '../../../../utils/date_format.dart';
import '../../../core/app_messenger.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/blur_hash_view.dart';
import '../../../core/widgets/glass_header_scaffold.dart';
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

    return GlassHeaderScaffold(
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
      // With no feeds the empty view offers the same action, so the FAB would
      // only duplicate it.
      //
      // This screen's Scaffold has no bottom bar of its own to lift the FAB
      // over: the tab bar belongs to HomeScreen's Scaffold, and `extendBody`
      // there runs this one to the bottom of the window. Nothing but the
      // padding keeps the two apart.
      floatingActionButton: hasFeeds
          ? Padding(
              padding: EdgeInsets.only(
                right: contentGutter(context),
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              child: FloatingActionButton(
                onPressed: () => _showAddDialog(context, ref),
                tooltip: 'Add feed',
                // Material 3 gives a FAB a rounded square; this one is round.
                shape: const CircleBorder(),
                child: const Icon(Icons.add),
              ),
            )
          : null,
      body: (context) => RefreshIndicator(
        // The list runs behind the header now, so the spinner is pushed clear
        // of it rather than turning underneath the glass.
        edgeOffset: MediaQuery.paddingOf(context).top,
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
      final chrome = MediaQuery.paddingOf(context);

      // The padding comes out of the minimum height as well as going around
      // the child, so the view centres between the header and the tab bar
      // rather than behind them.
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
      // The top clears the glass header; the bottom clears the FAB, and on
      // phones the floating tab bar beneath it.
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top,
        left: contentGutter(context),
        right: contentGutter(context),
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
      // The trailing menu button carries 12 points of its own padding, so the
      // theme's 16 would push its glyph to 28 from the edge. 4 puts it at the
      // 16 the divider and the app bar use.
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      leading: _FeedAvatar(feed: feed),
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

/// The feed's own icon, or its initial where there is none to draw.
///
/// Both are the same circle at the same size, so a list of feeds where only
/// some publish an icon still reads as one column.
class _FeedAvatar extends StatelessWidget {
  const _FeedAvatar({required this.feed});

  /// Matches the diameter [CircleAvatar] takes from its default radius.
  static const double _diameter = 40;

  final Feed feed;

  @override
  Widget build(BuildContext context) {
    final iconUrl = feed.iconUrl;
    if (iconUrl == null) return _placeholder(context);

    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    return ClipOval(
      child: Image.network(
        iconUrl,
        width: _diameter,
        height: _diameter,
        fit: BoxFit.cover,
        // Publishers routinely serve a 512 or 1024 pixel mark. Decoded at that
        // size it is megabytes in the image cache for a 40-point circle, and
        // the cache holds every feed in the list at once. Width only: both
        // dimensions together would stretch a mark that is not square.
        cacheWidth: (_diameter * pixelRatio).round(),
        // The placeholder holds the place until the icon arrives and stays if
        // it never does. A spinner in every row is a worse list than what it
        // replaces, and an icon that will not load is not worth telling the
        // user about.
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
            wasSynchronouslyLoaded || frame != null
            ? child
            : _placeholder(context),
        errorBuilder: (context, error, stackTrace) => _placeholder(context),
      ),
    );
  }

  /// The blur of the icon where one has been hashed, and the title's initial
  /// otherwise.
  ///
  /// The hash is the better stand-in and the only one that survives being
  /// offline: it is stored beside the URL, while the image behind that URL has
  /// no disk cache to fall back on.
  Widget _placeholder(BuildContext context) {
    final theme = Theme.of(context);
    final blurHash = feed.iconBlurHash;

    if (blurHash != null) {
      return SizedBox.square(
        dimension: _diameter,
        child: ClipOval(child: BlurHashView(hash: blurHash)),
      );
    }

    return CircleAvatar(
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Text(
        feed.title.characters.firstOrNull?.toUpperCase() ?? '?',
        style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
      ),
    );
  }
}
