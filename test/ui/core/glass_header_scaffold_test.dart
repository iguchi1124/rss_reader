import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rss_reader/ui/core/widgets/glass_header_scaffold.dart';
import 'package:rss_reader/ui/core/widgets/glass_surface.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassHeaderScaffold(
          title: const Text('Latest'),
          body: (context) => ListView(
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            children: [
              for (var index = 0; index < 40; index++)
                SizedBox(height: 40, child: Text('Item $index')),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('the body starts below the header rather than behind it', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(
      tester.getTopLeft(find.text('Item 0')).dy,
      greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
    );
  });

  testWidgets('the header carries no glass while the list is clear of it', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.byType(GlassSurface), findsNothing);
  });

  testWidgets('the header turns to glass once the list runs under it', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();

    final surface = tester.widget<GlassSurface>(find.byType(GlassSurface));
    expect(surface.blurSigma, greaterThan(0));
    expect(surface.opacity, greaterThan(0));
  });

  testWidgets('the glass goes again when the list is scrolled back to rest', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(find.byType(GlassSurface), findsNothing);
  });
}
