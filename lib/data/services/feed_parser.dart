import 'package:xml/xml.dart';

import '../../utils/result.dart';
import '../models/parsed_feed.dart';
import 'feed_date_parser.dart';
import 'html_text.dart';

/// Converts RSS 2.0, RSS 1.0 (RDF), and Atom into a [ParsedFeed].
///
/// The three formats differ in element names and nesting, and real-world feeds
/// declare namespaces inconsistently, so elements are matched on their local
/// name with any prefix ignored.
class FeedParser {
  const FeedParser();

  /// [feedUrl] is the base against which relative URLs are resolved.
  Result<ParsedFeed> parse(String xml, {String? feedUrl}) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(xml);
    } on XmlException catch (_, stackTrace) {
      return Failure(
        const FeedException('Could not parse the feed XML.'),
        stackTrace,
      );
    }

    final root = document.rootElement;
    return switch (root.name.local.toLowerCase()) {
      'rss' => _parseRss(root, feedUrl),
      'rdf' => _parseRdf(root, feedUrl),
      'feed' => _parseAtom(root, feedUrl),
      _ => const Failure(
        FeedException(
          'Unsupported format. Enter the URL of an RSS or Atom feed.',
        ),
      ),
    };
  }

  // --- RSS 2.0 -------------------------------------------------------------

  Result<ParsedFeed> _parseRss(XmlElement root, String? feedUrl) {
    final channel = _child(root, 'channel');
    if (channel == null) {
      return const Failure(
        FeedException('The RSS feed has no channel element.'),
      );
    }

    final siteUrl = resolveUrl(_text(channel, 'link'), baseUrl: feedUrl);

    return Ok(
      ParsedFeed(
        title: _feedTitle(_text(channel, 'title'), feedUrl),
        siteUrl: siteUrl,
        description: htmlToPlainText(_text(channel, 'description')),
        items: _children(
          channel,
          'item',
        ).map((item) => _parseRssItem(item, siteUrl ?? feedUrl)).toList(),
      ),
    );
  }

  ParsedItem _parseRssItem(XmlElement item, String? baseUrl) {
    final link = resolveUrl(_text(item, 'link'), baseUrl: baseUrl);

    // By RSS convention content:encoded carries the full body and description
    // an excerpt. Feeds that only supply description use it for both.
    final encoded = _text(item, 'encoded');
    final description = _text(item, 'description');
    final content = encoded ?? description;

    return ParsedItem(
      guid: _text(item, 'guid') ?? link ?? _text(item, 'title') ?? '',
      title: _itemTitle(_text(item, 'title')),
      link: link,
      author: _text(item, 'creator') ?? _text(item, 'author'),
      summary: htmlToPlainText(description ?? encoded, maxLength: 200),
      content: content,
      publishedAt: parseFeedDate(_text(item, 'pubDate') ?? _text(item, 'date')),
    );
  }

  // --- RSS 1.0 (RDF) -------------------------------------------------------

  /// RSS 1.0 places items directly under rdf:RDF rather than inside channel.
  Result<ParsedFeed> _parseRdf(XmlElement root, String? feedUrl) {
    final channel = _child(root, 'channel');
    if (channel == null) {
      return const Failure(
        FeedException('The RSS feed has no channel element.'),
      );
    }

    final siteUrl = resolveUrl(_text(channel, 'link'), baseUrl: feedUrl);

    return Ok(
      ParsedFeed(
        title: _feedTitle(_text(channel, 'title'), feedUrl),
        siteUrl: siteUrl,
        description: htmlToPlainText(_text(channel, 'description')),
        items: _children(
          root,
          'item',
        ).map((item) => _parseRssItem(item, siteUrl ?? feedUrl)).toList(),
      ),
    );
  }

  // --- Atom ----------------------------------------------------------------

  Result<ParsedFeed> _parseAtom(XmlElement root, String? feedUrl) {
    final siteUrl = _atomLink(root, baseUrl: feedUrl);

    return Ok(
      ParsedFeed(
        title: _feedTitle(_text(root, 'title'), feedUrl),
        siteUrl: siteUrl,
        description: htmlToPlainText(
          _text(root, 'subtitle') ?? _text(root, 'tagline'),
        ),
        items: _children(
          root,
          'entry',
        ).map((entry) => _parseAtomEntry(entry, siteUrl ?? feedUrl)).toList(),
      ),
    );
  }

  ParsedItem _parseAtomEntry(XmlElement entry, String? baseUrl) {
    final link = _atomLink(entry, baseUrl: baseUrl);
    final summary = _text(entry, 'summary');
    final content = _text(entry, 'content');

    return ParsedItem(
      guid: _text(entry, 'id') ?? link ?? _text(entry, 'title') ?? '',
      title: _itemTitle(_text(entry, 'title')),
      link: link,
      author: _child(entry, 'author') == null
          ? null
          : _text(_child(entry, 'author')!, 'name'),
      summary: htmlToPlainText(summary ?? content, maxLength: 200),
      content: content ?? summary,
      // Some Atom feeds only carry updated, so published is preferred but not
      // required.
      publishedAt: parseFeedDate(
        _text(entry, 'published') ?? _text(entry, 'updated'),
      ),
    );
  }

  /// Picks the URL of the readable page out of Atom's link elements.
  ///
  /// rel="alternate" points at that page, and a missing rel is treated the same
  /// way. rel="self" refers to the feed document and is skipped.
  String? _atomLink(XmlElement parent, {String? baseUrl}) {
    XmlElement? fallback;

    for (final link in _children(parent, 'link')) {
      final rel = link.getAttribute('rel');
      if (rel == 'alternate' || rel == null) {
        return resolveUrl(link.getAttribute('href'), baseUrl: baseUrl);
      }
      if (rel != 'self') fallback ??= link;
    }

    return resolveUrl(fallback?.getAttribute('href'), baseUrl: baseUrl);
  }

  // --- Shared helpers -------------------------------------------------------

  String _feedTitle(String? raw, String? feedUrl) {
    final title = htmlToPlainText(raw);
    if (title != null) return title;
    // Untitled feeds still need to be distinguishable in the list.
    final host = feedUrl == null ? null : Uri.tryParse(feedUrl)?.host;
    return (host == null || host.isEmpty) ? 'Untitled feed' : host;
  }

  String _itemTitle(String? raw) => htmlToPlainText(raw) ?? '(untitled)';

  XmlElement? _child(XmlElement parent, String localName) {
    for (final element in parent.childElements) {
      if (element.name.local == localName) return element;
    }
    return null;
  }

  Iterable<XmlElement> _children(XmlElement parent, String localName) =>
      parent.childElements.where((e) => e.name.local == localName);

  /// Empty text counts as absent and comes back as null.
  String? _text(XmlElement parent, String localName) {
    final element = _child(parent, localName);
    if (element == null) return null;
    final value = element.innerText.trim();
    return value.isEmpty ? null : value;
  }
}
