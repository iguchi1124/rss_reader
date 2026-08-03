import 'package:flutter/foundation.dart';

@immutable
class Feed {
  const Feed({
    required this.id,
    required this.title,
    required this.feedUrl,
    this.siteUrl,
    this.iconUrl,
    this.description,
    this.lastFetchedAt,
    this.unreadCount = 0,
    this.totalCount = 0,
  });

  final int id;
  final String title;

  /// URL of the RSS/Atom document itself.
  final String feedUrl;

  /// Home page the feed points at.
  final String? siteUrl;

  /// Image standing in for the feed in lists. Null where neither the feed nor
  /// its site offered one that can be drawn, and the initial is shown instead.
  final String? iconUrl;

  final String? description;
  final DateTime? lastFetchedAt;

  /// Aggregated by the database query rather than stored on the feed row.
  final int unreadCount;
  final int totalCount;

  Feed copyWith({
    String? title,
    String? siteUrl,
    String? iconUrl,
    String? description,
    DateTime? lastFetchedAt,
    int? unreadCount,
    int? totalCount,
  }) {
    return Feed(
      id: id,
      title: title ?? this.title,
      feedUrl: feedUrl,
      siteUrl: siteUrl ?? this.siteUrl,
      iconUrl: iconUrl ?? this.iconUrl,
      description: description ?? this.description,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      unreadCount: unreadCount ?? this.unreadCount,
      totalCount: totalCount ?? this.totalCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Feed &&
      other.id == id &&
      other.title == title &&
      other.feedUrl == feedUrl &&
      other.siteUrl == siteUrl &&
      other.iconUrl == iconUrl &&
      other.description == description &&
      other.lastFetchedAt == lastFetchedAt &&
      other.unreadCount == unreadCount &&
      other.totalCount == totalCount;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    feedUrl,
    siteUrl,
    iconUrl,
    description,
    lastFetchedAt,
    unreadCount,
    totalCount,
  );
}
