import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../../utils/result.dart';
import 'html_text.dart';

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

  Future<Result<String>> fetch(String url) async {
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
          .timeout(_timeout);

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

  void dispose() => _httpClient.close();
}
