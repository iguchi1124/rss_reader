import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../../../data/services/html_text.dart';

/// Renders article HTML as Flutter widgets.
///
/// Feed bodies stick to a narrow set of tags — headings, lists, quotes, code,
/// images — so that range is rendered directly rather than pulling in a WebView.
/// Anything outside it degrades to its text content.
class HtmlContent extends StatefulWidget {
  const HtmlContent({
    super.key,
    required this.html,
    this.baseUrl,
    this.onLinkTap,
  });

  final String html;

  /// Base for relative URLs; pass the article's own URL.
  final String? baseUrl;

  final ValueChanged<String>? onLinkTap;

  @override
  State<HtmlContent> createState() => _HtmlContentState();
}

class _HtmlContentState extends State<HtmlContent> {
  /// Held so they can be disposed with the widget rather than leaking.
  final _recognizers = <TapGestureRecognizer>[];

  List<Widget> _blocks = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Built here, not in build, because the text styles come from the Theme.
    _rebuild();
  }

  @override
  void didUpdateWidget(HtmlContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html || oldWidget.baseUrl != widget.baseUrl) {
      _rebuild();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _rebuild() {
    _disposeRecognizers();
    _blocks = _HtmlBuilder(
      theme: Theme.of(context),
      baseUrl: widget.baseUrl,
      onLinkTap: widget.onLinkTap,
      recognizers: _recognizers,
    ).build(widget.html);
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _blocks,
    );
  }
}

class _HtmlBuilder {
  _HtmlBuilder({
    required this.theme,
    required this.baseUrl,
    required this.onLinkTap,
    required this.recognizers,
  });

  final ThemeData theme;
  final String? baseUrl;
  final ValueChanged<String>? onLinkTap;
  final List<TapGestureRecognizer> recognizers;

  /// Generous, so wrapped paragraphs stay readable.
  static const _lineHeight = 1.7;

  static const _ignoredTags = {
    'script',
    'style',
    'noscript',
    'iframe',
    'object',
    'embed',
    'svg',
    'form',
    'button',
    'input',
  };

  static const _blockTags = {
    'p', 'div', 'section', 'article', 'header', 'footer', 'main', 'aside', //
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
    'ul', 'ol', 'li', 'dl', 'dt', 'dd',
    'blockquote', 'pre', 'hr', 'table', 'figure', 'figcaption', 'img',
  };

  TextStyle get _baseStyle =>
      (theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16)).copyWith(
        height: _lineHeight,
        color: theme.colorScheme.onSurface,
      );

  List<Widget> build(String html) {
    final body = html_parser.parse(html).body;
    if (body == null) return const [];
    return _blocksFrom(body.nodes, _baseStyle);
  }

  /// Runs of inline nodes collect into one paragraph, which is closed off as
  /// soon as a block element appears.
  List<Widget> _blocksFrom(List<dom.Node> nodes, TextStyle style) {
    final blocks = <Widget>[];
    final pending = <InlineSpan>[];

    void flush() {
      final spans = _trim(pending);
      if (spans.isNotEmpty) blocks.add(_paragraph(spans));
      pending.clear();
    }

    for (final node in nodes) {
      if (node is dom.Element && _blockTags.contains(node.localName)) {
        flush();
        blocks.addAll(_blockFor(node, style));
      } else {
        pending.addAll(_inlineFrom(node, style));
      }
    }
    flush();

    return blocks;
  }

  List<Widget> _blockFor(dom.Element element, TextStyle style) {
    final tag = element.localName;
    if (_ignoredTags.contains(tag)) return const [];

    switch (tag) {
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        return [_heading(element, tag!)];

      case 'p':
        final spans = _trim(_inlineChildren(element, style));
        return spans.isEmpty ? const [] : [_paragraph(spans)];

      case 'ul' || 'ol':
        return [_list(element, style, ordered: tag == 'ol')];

      case 'blockquote':
        return [_blockquote(element, style)];

      case 'pre':
        return [_codeBlock(element)];

      case 'hr':
        return [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),
        ];

      case 'img':
        final image = _image(element);
        return image == null ? const [] : [image];

      case 'figcaption':
        final spans = _trim(_inlineChildren(element, _captionStyle));
        return spans.isEmpty
            ? const []
            : [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text.rich(
                    TextSpan(children: spans),
                    textAlign: TextAlign.center,
                  ),
                ),
              ];

      case 'table':
        return _table(element, style);

      // ul/ol handle their own li children, so only orphaned ones land here.
      // Everything else is treated as a pass-through container.
      default:
        return _blocksFrom(element.nodes, style);
    }
  }

  Widget _paragraph(List<InlineSpan> spans) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text.rich(TextSpan(children: spans)),
    );
  }

  Widget _heading(dom.Element element, String tag) {
    final level = int.parse(tag.substring(1));
    final textTheme = theme.textTheme;

    // h1/h2 read as headings; h3 and below sit closer to body size.
    final style = switch (level) {
      1 => textTheme.headlineSmall,
      2 => textTheme.titleLarge,
      3 => textTheme.titleMedium,
      _ => textTheme.titleSmall,
    };

    final resolved = (style ?? _baseStyle).copyWith(
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
    );

    final spans = _trim(_inlineChildren(element, resolved));
    if (spans.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: level <= 2 ? 16 : 12, bottom: 10),
      child: Text.rich(TextSpan(children: spans)),
    );
  }

  Widget _list(dom.Element element, TextStyle style, {required bool ordered}) {
    final items = element.children.where((e) => e.localName == 'li').toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, item) in items.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      ordered ? '${index + 1}.' : '•',
                      style: style.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // An li can hold paragraphs or nested lists, hence recursion.
                  Expanded(child: _listItemBody(item, style)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _listItemBody(dom.Element item, TextStyle style) {
    final blocks = _blocksFrom(item.nodes, style);
    if (blocks.isEmpty) return const SizedBox.shrink();

    // Full paragraph spacing between bullets would look stretched out.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in blocks)
          if (block is Padding &&
              block.padding == const EdgeInsets.only(bottom: 16))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: block.child,
            )
          else
            block,
      ],
    );
  }

  Widget _blockquote(dom.Element element, TextStyle style) {
    final quoteStyle = style.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontStyle: FontStyle.italic,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _blocksFrom(element.nodes, quoteStyle),
      ),
    );
  }

  Widget _codeBlock(dom.Element element) {
    // Whitespace and newlines are significant inside pre, so the inline
    // collapsing path is bypassed.
    final code = element.text.trimRight();
    if (code.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(code, style: _monospace.copyWith(height: 1.5)),
      ),
    );
  }

  Widget? _image(dom.Element element) {
    final src = resolveUrl(
      element.attributes['src'] ?? element.attributes['data-src'],
      baseUrl: baseUrl,
    );
    if (src == null || !src.startsWith('http')) return null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          src,
          fit: BoxFit.contain,
          // A broken image should not leave a gap in the article.
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }

  /// Laid out as text per row: column widths cannot be resolved reliably from
  /// feed markup.
  List<Widget> _table(dom.Element element, TextStyle style) {
    final rows = element.querySelectorAll('tr');
    if (rows.isEmpty) return const [];

    return [
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            for (final (index, row) in rows.indexed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: index == 0
                      ? null
                      : Border(
                          top: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                ),
                child: Text(
                  row.children
                      .map((cell) => cell.text.trim())
                      .where((text) => text.isNotEmpty)
                      .join(' / '),
                  style: style,
                ),
              ),
          ],
        ),
      ),
    ];
  }

  // --- Inline ---------------------------------------------------------------

  List<InlineSpan> _inlineChildren(dom.Element element, TextStyle style) => [
    for (final node in element.nodes) ..._inlineFrom(node, style),
  ];

  List<InlineSpan> _inlineFrom(dom.Node node, TextStyle style) {
    if (node is dom.Text) {
      // HTML collapses any run of whitespace into a single space.
      final text = node.text.replaceAll(RegExp(r'\s+'), ' ');
      return text.isEmpty ? const [] : [TextSpan(text: text, style: style)];
    }

    if (node is! dom.Element) return const [];

    final tag = node.localName;
    if (_ignoredTags.contains(tag)) return const [];

    switch (tag) {
      case 'br':
        return const [TextSpan(text: '\n')];

      case 'strong' || 'b':
        return _inlineChildren(
          node,
          style.copyWith(fontWeight: FontWeight.w600),
        );

      case 'em' || 'i' || 'cite' || 'dfn':
        return _inlineChildren(
          node,
          style.copyWith(fontStyle: FontStyle.italic),
        );

      case 'u' || 'ins':
        return _inlineChildren(
          node,
          style.copyWith(decoration: TextDecoration.underline),
        );

      case 's' || 'del' || 'strike':
        return _inlineChildren(
          node,
          style.copyWith(decoration: TextDecoration.lineThrough),
        );

      case 'code' || 'kbd' || 'samp' || 'tt' || 'var':
        return _inlineChildren(
          node,
          style
              .merge(_monospace)
              .copyWith(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
        );

      case 'small':
        return _inlineChildren(
          node,
          style.copyWith(fontSize: (style.fontSize ?? 16) * 0.85),
        );

      case 'mark':
        return _inlineChildren(
          node,
          style.copyWith(
            backgroundColor: theme.colorScheme.primaryContainer,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        );

      case 'a':
        return _link(node, style);

      default:
        return _inlineChildren(node, style);
    }
  }

  List<InlineSpan> _link(dom.Element element, TextStyle style) {
    final href = resolveUrl(element.attributes['href'], baseUrl: baseUrl);
    final linkStyle = style.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary.withValues(alpha: 0.4),
    );

    final children = _inlineChildren(element, linkStyle);
    if (href == null || onLinkTap == null || children.isEmpty) {
      // A link that cannot be followed reads better undecorated.
      return href == null ? _inlineChildren(element, style) : children;
    }

    final recognizer = TapGestureRecognizer()..onTap = () => onLinkTap!(href);
    recognizers.add(recognizer);

    return _attachRecognizer(children, recognizer);
  }

  /// Puts [recognizer] on every span in the subtree.
  ///
  /// A recogniser on a parent span is never consulted for its children: a tap
  /// resolves to the innermost span covering that offset, so each leaf needs
  /// its own reference for nested markup such as `<a><strong>…`.
  List<InlineSpan> _attachRecognizer(
    List<InlineSpan> spans,
    TapGestureRecognizer recognizer,
  ) {
    return [
      for (final span in spans)
        if (span is TextSpan)
          TextSpan(
            text: span.text,
            style: span.style,
            children: span.children == null
                ? null
                : _attachRecognizer(span.children!, recognizer),
            recognizer: recognizer,
          )
        else
          span,
    ];
  }

  // --- Helpers --------------------------------------------------------------

  TextStyle get _monospace => const TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['Menlo', 'Courier New', 'monospace'],
    fontSize: 14,
  );

  TextStyle get _captionStyle => _baseStyle.copyWith(
    fontSize: 13,
    color: theme.colorScheme.onSurfaceVariant,
  );

  /// Returns an empty list when nothing but whitespace is left, which tells the
  /// caller to drop the paragraph entirely.
  List<InlineSpan> _trim(List<InlineSpan> spans) {
    if (spans.isEmpty) return const [];

    final result = List<InlineSpan>.from(spans);

    InlineSpan? edit(InlineSpan span, String Function(String) transform) {
      if (span is! TextSpan || span.text == null) return span;
      final text = transform(span.text!);
      if (text.isEmpty && (span.children?.isEmpty ?? true)) return null;
      return TextSpan(
        text: text,
        style: span.style,
        children: span.children,
        recognizer: span.recognizer,
      );
    }

    while (result.isNotEmpty) {
      final trimmed = edit(result.first, (text) => text.trimLeft());
      if (trimmed == null) {
        result.removeAt(0);
        continue;
      }
      result[0] = trimmed;
      break;
    }

    while (result.isNotEmpty) {
      final trimmed = edit(result.last, (text) => text.trimRight());
      if (trimmed == null) {
        result.removeLast();
        continue;
      }
      result[result.length - 1] = trimmed;
      break;
    }

    final hasContent = result.any(
      (span) =>
          span.toPlainText(includeSemanticsLabels: false).trim().isNotEmpty,
    );
    return hasContent ? result : const [];
  }
}
