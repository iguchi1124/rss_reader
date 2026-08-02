import 'package:flutter/foundation.dart';

@immutable
class Article {
  const Article({
    required this.id,
    required this.feedId,
    required this.guid,
    required this.title,
    this.feedTitle,
    this.link,
    this.author,
    this.summary,
    this.content,
    this.publishedAt,
    required this.fetchedAt,
    this.isRead = false,
    this.isStarred = false,
  });

  final int id;
  final int feedId;

  /// Identifies the entry within its feed; used to detect re-fetched articles.
  final String guid;

  final String title;

  /// Only populated when the row was joined against its feed.
  final String? feedTitle;

  final String? link;
  final String? author;

  /// Short excerpt with HTML stripped.
  final String? summary;

  /// Body HTML, rendered on the detail screen.
  final String? content;

  final DateTime? publishedAt;
  final DateTime fetchedAt;
  final bool isRead;
  final bool isStarred;

  /// Falls back to the fetch time for feeds that omit publication dates.
  DateTime get displayDate => publishedAt ?? fetchedAt;

  Article copyWith({bool? isRead, bool? isStarred}) {
    return Article(
      id: id,
      feedId: feedId,
      guid: guid,
      title: title,
      feedTitle: feedTitle,
      link: link,
      author: author,
      summary: summary,
      content: content,
      publishedAt: publishedAt,
      fetchedAt: fetchedAt,
      isRead: isRead ?? this.isRead,
      isStarred: isStarred ?? this.isStarred,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Article &&
      other.id == id &&
      other.feedId == feedId &&
      other.guid == guid &&
      other.title == title &&
      other.feedTitle == feedTitle &&
      other.link == link &&
      other.author == author &&
      other.summary == summary &&
      other.content == content &&
      other.publishedAt == publishedAt &&
      other.fetchedAt == fetchedAt &&
      other.isRead == isRead &&
      other.isStarred == isStarred;

  @override
  int get hashCode => Object.hash(
    id,
    feedId,
    guid,
    title,
    feedTitle,
    link,
    author,
    summary,
    content,
    publishedAt,
    fetchedAt,
    isRead,
    isStarred,
  );
}

enum ArticleFilter {
  all('All'),
  unread('Unread'),
  starred('Starred');

  const ArticleFilter(this.label);

  final String label;
}
