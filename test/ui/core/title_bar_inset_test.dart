import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rss_reader/ui/core/title_bar_inset.dart';

void main() {
  Future<EdgeInsets> paddingOn(
    WidgetTester tester,
    TargetPlatform platform,
  ) async {
    late EdgeInsets padding;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: TitleBarInset(
          child: Builder(
            builder: (context) {
              padding = MediaQuery.paddingOf(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    return padding;
  }

  testWidgets('reserves the title bar on macOS', (tester) async {
    final padding = await paddingOn(tester, TargetPlatform.macOS);

    expect(padding.top, macOSTitleBarHeight);
  });

  testWidgets('leaves the system insets alone elsewhere', (tester) async {
    final padding = await paddingOn(tester, TargetPlatform.iOS);

    expect(padding.top, 0);
  });
}
