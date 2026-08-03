import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../../utils/result.dart';
import 'html_text.dart';

const _undrawableExtensions = {'.ico', '.svg', '.svgz'};
const _undrawableTypes = {
  'image/x-icon',
  'image/vnd.microsoft.icon',
  'image/svg+xml',
};

/// Whether Flutter can draw the image at [url].
///
/// `dart:ui` has no ICO or SVG codec (flutter/flutter#105848), and `.ico` is
/// still what most sites advertise, so an icon that fails this is not worth
/// storing: it would fail on every build rather than resolve into anything.
///
/// Extension and declared [type] are all there is to go on without fetching the
/// bytes. Anything unrecognised passes, and the widget showing it falls back on
/// its own if the guess was wrong.
bool isDrawableImageUrl(String url, {String? type}) {
  if (type != null && _undrawableTypes.contains(type.toLowerCase().trim())) {
    return false;
  }
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
  return !_undrawableExtensions.any((extension) => path.endsWith(extension));
}

/// HTTP access to feed publishers.
///
/// Goes no further than turning a response into a string; parsing and storage
/// happen elsewhere.
class FeedApiClient {
  FeedApiClient({http.Client? httpClient, Duration? timeout})
    : _httpClient = httpClient ?? http.Client(),
      _timeout = timeout ?? const Duration(seconds: 20);

  final http.Client _httpClient;
  final Duration _timeout;

  /// Sent explicitly because some hosts reject requests without a User-Agent.
  static const _userAgent = 'rss_reader/1.0 (+https://github.com/iguchi1124/rss_reader)';

  /// [timeout] overrides the client's own, for a request whose result matters
  /// less than the wait — see `FeedRepository._findSiteIcon`.
  Future<Result<String>> fetch(String url, {Duration? timeout}) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return const Failure(FeedException('That URL is not valid.'));
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return const Failure(FeedException('Enter an http or https URL.'));
    }

    try {
      final response = await _httpClient
          .get(uri, headers: const {'User-Agent': _userAgent, 'Accept': '*/*'})
          .timeout(timeout ?? _timeout);

      if (response.statusCode != 200) {
        return Failure(
          FeedException('Fetch failed (HTTP ${response.statusCode}).'),
        );
      }

      return Ok(_decode(response));
    } on SocketException catch (_, stackTrace) {
      return Failure(
        const FeedException('Could not connect. Check your network.'),
        stackTrace,
      );
    } on http.ClientException catch (error, stackTrace) {
      return Failure(
        FeedException('Request failed: ${error.message}'),
        stackTrace,
      );
    } on Exception catch (error, stackTrace) {
      return Failure(FeedException('Fetch failed: $error'), stackTrace);
    }
  }

  /// Decodes the response body.
  ///
  /// [http.Response.body] falls back to Latin-1 when no charset is declared,
  /// which mangles non-ASCII feeds. Undeclared bodies are overwhelmingly UTF-8,
  /// so that is assumed instead.
  String _decode(http.Response response) {
    final charset = response.headers['content-type']
        ?.split(';')
        .map((part) => part.trim().toLowerCase())
        .firstWhere((part) => part.startsWith('charset='), orElse: () => '')
        .replaceFirst('charset=', '')
        .replaceAll('"', '');

    if (charset != null && charset.isNotEmpty && charset != 'utf-8') {
      final codec = Encoding.getByName(charset);
      if (codec != null) return codec.decode(response.bodyBytes);
    }

    // The XML declaration's own encoding is still readable after a lenient
    // UTF-8 decode, so malformed bytes are tolerated rather than fatal.
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  /// Finds a feed URL advertised by an HTML page.
  ///
  /// Users typically paste a site URL, so `<link rel="alternate">` is followed
  /// to reach the actual feed.
  String? discoverFeedUrl(String html, {required String baseUrl}) {
    final document = html_parser.parse(html);

    const feedTypes = {
      'application/rss+xml',
      'application/atom+xml',
      'application/rdf+xml',
      'application/xml',
      'text/xml',
    };

    for (final link in document.querySelectorAll('link')) {
      final rel = link.attributes['rel']?.toLowerCase();
      if (rel != 'alternate') continue;

      final type = link.attributes['type']?.toLowerCase().trim();
      if (type == null || !feedTypes.contains(type)) continue;

      final href = resolveUrl(link.attributes['href'], baseUrl: baseUrl);
      if (href != null) return href;
    }

    return null;
  }

  /// Finds the icon an HTML page advertises for itself.
  ///
  /// `rel="icon"` and `rel="apple-touch-icon"` are both candidates and the
  /// largest declared size wins: the feed list draws these at 40 points, and a
  /// 16-pixel favicon is visibly soft there.
  ///
  /// Anything [isDrawableImageUrl] rejects is dropped rather than stored, and
  /// `.ico` is still what most sites advertise, so this returns null for a good
  /// many pages.
  String? discoverIconUrl(String html, {required String baseUrl}) {
    final document = html_parser.parse(html);

    String? best;
    var bestSize = -1;

    for (final link in document.querySelectorAll('link')) {
      final rels =
          link.attributes['rel']?.toLowerCase().split(RegExp(r'\s+')) ??
          const <String>[];
      final isTouchIcon = rels.contains('apple-touch-icon');
      if (!isTouchIcon && !rels.contains('icon')) continue;

      final href = resolveUrl(link.attributes['href'], baseUrl: baseUrl);
      if (href == null ||
          !isDrawableImageUrl(href, type: link.attributes['type'])) {
        continue;
      }

      // An apple-touch-icon seldom declares a size and is 180 by convention,
      // which is the one worth having when nothing else says how big it is.
      final size =
          _declaredSize(link.attributes['sizes']) ?? (isTouchIcon ? 180 : 0);
      if (size > bestSize) {
        bestSize = size;
        best = href;
      }
    }

    return best;
  }

  /// The largest width the `sizes` attribute names, or null where it names none
  /// — `sizes="any"` says nothing about pixels.
  int? _declaredSize(String? sizes) {
    var largest = 0;
    for (final token
        in sizes?.toLowerCase().split(RegExp(r'\s+')) ?? const <String>[]) {
      final width = int.tryParse(token.split('x').first);
      if (width != null && width > largest) largest = width;
    }
    return largest == 0 ? null : largest;
  }

  void dispose() => _httpClient.close();
}
