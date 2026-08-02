import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rss_reader/ui/core/widgets/html_content.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    String html, {
    String? baseUrl,
    ValueChanged<String>? onLinkTap,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HtmlContent(
              html: html,
              baseUrl: baseUrl,
              onLinkTap: onLinkTap,
            ),
          ),
        ),
      ),
    );
  }

  String renderedText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
      .join('\n');

  testWidgets('renders paragraphs', (tester) async {
    await pump(tester, '<p>First</p><p>Second</p>');
    expect(renderedText(tester), contains('First'));
    expect(renderedText(tester), contains('Second'));
  });

  testWidgets('renders headings in bold', (tester) async {
    await pump(tester, '<h1>Heading</h1>');

    final text = tester.widget<Text>(find.byType(Text).first);
    final span = text.textSpan! as TextSpan;
    expect(span.toPlainText(), 'Heading');
    expect(
      (span.children!.first as TextSpan).style?.fontWeight,
      FontWeight.w700,
    );
  });

  testWidgets('marks unordered list items with a bullet', (tester) async {
    await pump(tester, '<ul><li>Apple</li><li>Orange</li></ul>');

    final rendered = renderedText(tester);
    expect(rendered, contains('•'));
    expect(rendered, contains('Apple'));
    expect(rendered, contains('Orange'));
  });

  testWidgets('numbers ordered list items', (tester) async {
    await pump(tester, '<ol><li>One</li><li>Two</li></ol>');

    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
  });

  testWidgets('passes the tapped link URL to the callback', (tester) async {
    String? tapped;
    // The href stays non-ASCII on purpose: it is what exercises percent-encoding.
    await pump(
      tester,
      '<p><a href="/記事">link</a></p>',
      baseUrl: 'https://example.com/base/',
      onLinkTap: (url) => tapped = url,
    );

    // The paragraph fills the width while the text is left-aligned, so tapping
    // the widget's centre would miss the glyphs the recogniser is attached to.
    await tester.tapAt(
      tester.getTopLeft(find.byType(RichText).first) + const Offset(8, 8),
    );
    await tester.pump();

    // Percent-encoded because the relative href was resolved against baseUrl.
    expect(tapped, 'https://example.com/%E8%A8%98%E4%BA%8B');
  });

  testWidgets('does not render script or style', (tester) async {
    await pump(
      tester,
      '<p>Body</p><script>alert(1)</script><style>p{color:red}</style>',
    );

    final rendered = renderedText(tester);
    expect(rendered, contains('Body'));
    expect(rendered, isNot(contains('alert')));
    expect(rendered, isNot(contains('color:red')));
  });

  testWidgets('preserves newlines and spacing inside pre', (tester) async {
    await pump(tester, '<pre><code>a\n  b</code></pre>');
    expect(renderedText(tester), contains('a\n  b'));
  });

  testWidgets('collapses runs of whitespace', (tester) async {
    await pump(tester, '<p>a   b\n\nc</p>');
    expect(renderedText(tester), contains('a b c'));
  });

  testWidgets('drops paragraphs that hold only whitespace', (tester) async {
    await pump(tester, '<p>   </p><p></p><p>Body</p>');
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('renders bare text with no tags', (tester) async {
    await pump(tester, 'body with no tags');
    expect(renderedText(tester), contains('body with no tags'));
  });

  testWidgets('breaks the line on br', (tester) async {
    await pump(tester, 'above<br/>below');
    expect(renderedText(tester), contains('above\nbelow'));
  });

  testWidgets('keeps only the contents of an unknown tag', (tester) async {
    await pump(tester, '<custom-tag>contents</custom-tag>');
    expect(renderedText(tester), contains('contents'));
  });

  testWidgets('wraps a blockquote in its own container', (tester) async {
    await pump(tester, '<blockquote><p>Quoted</p></blockquote>');
    expect(renderedText(tester), contains('Quoted'));
    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('re-renders when the html changes', (tester) async {
    await pump(tester, '<p>Before</p>');
    expect(renderedText(tester), contains('Before'));

    await pump(tester, '<p>After</p>');
    expect(renderedText(tester), contains('After'));
    expect(renderedText(tester), isNot(contains('Before')));
  });
}
