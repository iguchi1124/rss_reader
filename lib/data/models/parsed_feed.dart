/// A feed as read out of XML, before it reaches the database.
class ParsedFeed {
  const ParsedFeed({
    required this.title,
    this.siteUrl,
    this.description,
    this.items = const [],
  });

  final String title;
  final String? siteUrl;
  final String? description;
  final List<ParsedItem> items;
}

/// One entry of a [ParsedFeed].
class ParsedItem {
  const ParsedItem({
    required this.guid,
    required this.title,
    this.link,
    this.author,
    this.summary,
    this.content,
    this.publishedAt,
  });

  final String guid;
  final String title;
  final String? link;
  final String? author;
  final String? summary;
  final String? content;
  final DateTime? publishedAt;
}
