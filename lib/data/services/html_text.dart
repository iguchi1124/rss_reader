import 'package:html/parser.dart' as html_parser;

/// Used for list excerpts and for fields such as titles, where feeds sometimes
/// smuggle in markup.
String? htmlToPlainText(String? html, {int? maxLength}) {
  if (html == null) return null;

  final trimmed = html.trim();
  if (trimmed.isEmpty) return null;

  // The parser handles entity expansion as well as tag removal.
  final text = html_parser.parse(trimmed).body?.text ?? '';
  final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.isEmpty) return null;

  if (maxLength == null || collapsed.length <= maxLength) return collapsed;
  return '${collapsed.substring(0, maxLength).trimRight()}…';
}

/// Resolves against [baseUrl], since some feeds write article links and image
/// sources as relative paths.
String? resolveUrl(String? url, {String? baseUrl}) {
  final value = url?.trim();
  if (value == null || value.isEmpty) return null;

  final parsed = Uri.tryParse(value);
  if (parsed == null) return null;
  if (parsed.hasScheme) return parsed.toString();

  final base = baseUrl == null ? null : Uri.tryParse(baseUrl);
  if (base == null || !base.hasScheme) return value;

  return base.resolveUri(parsed).toString();
}
