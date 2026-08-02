import 'package:flutter/foundation.dart';

@immutable
class Feed {
  const Feed({
    required this.id,
    required this.title,
    required this.feedUrl,
    this.siteUrl,
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
  final String? description;
  final DateTime? lastFetchedAt;

  /// Aggregated by the database query rather than stored on the feed row.
  final int unreadCount;
  final int totalCount;

  Feed copyWith({
    String? title,
    String? siteUrl,
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
    description,
    lastFetchedAt,
    unreadCount,
    totalCount,
  );
}
