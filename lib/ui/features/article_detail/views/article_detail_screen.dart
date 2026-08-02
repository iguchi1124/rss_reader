import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/article.dart';
import '../../../../utils/date_format.dart';
import '../../../core/link_launcher.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/html_content.dart';
import '../view_models/article_detail_view_model.dart';

class ArticleDetailScreen extends ConsumerStatefulWidget {
  const ArticleDetailScreen({super.key, required this.article});

  final Article article;

  @override
  ConsumerState<ArticleDetailScreen> createState() =>
      _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends ConsumerState<ArticleDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Once per visit: leaving before finishing should not undo it, and marking
    // the article unread again should stick.
    if (!widget.article.isRead) {
      ref.read(articleProvider(widget.article.id).notifier).setRead(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.read(articleProvider(widget.article.id).notifier);
    // The article disappears once its feed is deleted; keep showing the copy the
    // screen was opened with.
    final article =
        ref.watch(articleProvider(widget.article.id)).value ?? widget.article;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          article.feedTitle ?? '',
          style: theme.textTheme.titleSmall,
          overflow: TextOverflow.ellipsis,
        ),
        actionsPadding: appBarActionsPadding(context),
        actions: [
          IconButton(
            onPressed: () => viewModel.toggleStarred(article),
            icon: Icon(
              article.isStarred ? Icons.star : Icons.star_border,
              color: article.isStarred ? theme.colorScheme.primary : null,
            ),
            tooltip: article.isStarred ? 'Remove star' : 'Add star',
          ),
          IconButton(
            onPressed: () => openExternalLink(
              context,
              article.link,
              emptyMessage: 'This article has no link.',
            ),
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Open in browser',
          ),
          PopupMenuButton<_DetailAction>(
            onSelected: (action) => _onAction(viewModel, action),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _DetailAction.markUnread,
                child: ListTile(
                  leading: Icon(Icons.mark_email_unread_outlined),
                  title: Text('Mark as unread'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SelectionArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 16, 20 + rightGutter(context), 48),
          children: [
            Text(
              article.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            _Meta(article: article),
            const Divider(height: 32),
            if (article.content case final content?)
              HtmlContent(
                html: content,
                baseUrl: article.link,
                onLinkTap: (url) => openExternalLink(context, url),
              )
            else
              _NoContent(link: article.link),
          ],
        ),
      ),
    );
  }

  void _onAction(ArticleDetailViewModel viewModel, _DetailAction action) {
    switch (action) {
      case _DetailAction.markUnread:
        // Closing immediately is what makes this stick: staying on the detail
        // screen would look as though the article had been re-read.
        viewModel.setRead(false);
        Navigator.of(context).pop();
    }
  }
}

enum _DetailAction { markUnread }

class _Meta extends StatelessWidget {
  const _Meta({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final parts = [?article.author, formatFullDate(article.displayDate)];

    return Text(parts.join(' · '), style: style);
  }
}

/// Shown for feeds that publish headlines without article bodies.
class _NoContent extends StatelessWidget {
  const _NoContent({required this.link});

  final String? link;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This feed does not publish article bodies.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (link != null) ...[
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => openExternalLink(context, link),
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Read in browser'),
          ),
        ],
      ],
    );
  }
}
