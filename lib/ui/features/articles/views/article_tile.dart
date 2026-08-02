import 'package:flutter/material.dart';

import '../../../../domain/models/article.dart';
import '../../../../utils/date_format.dart';

class ArticleTile extends StatelessWidget {
  const ArticleTile({
    super.key,
    required this.article,
    required this.onTap,
    required this.onToggleStarred,
    this.showFeedTitle = true,
  });

  final Article article;
  final VoidCallback onTap;
  final VoidCallback onToggleStarred;

  /// Turned off within a single feed, where the publisher is already obvious.
  final bool showFeedTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !article.isRead;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unread marker. Stays in the layout when read so rows don't shift.
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnread
                    ? theme.colorScheme.primary
                    : Colors.transparent,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                      color: isUnread
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (article.summary case final summary?) ...[
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (showFeedTitle && article.feedTitle != null)
                        article.feedTitle!,
                      formatRelativeDate(article.displayDate),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onToggleStarred,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                article.isStarred ? Icons.star : Icons.star_border,
                size: 20,
                color: article.isStarred
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              tooltip: article.isStarred ? 'Remove star' : 'Add star',
            ),
          ],
        ),
      ),
    );
  }
}
