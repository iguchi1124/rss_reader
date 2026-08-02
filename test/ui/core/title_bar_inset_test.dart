import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rss_reader/ui/core/title_bar_inset.dart';

void main() {
  const systemInset = 20.0;
  const titleBarHeight = 28.0;

  late TestDefaultBinaryMessenger messenger;
  late EdgeInsets padding;

  setUp(() {
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  });

  tearDown(() => messenger.setMockMethodCallHandler(titleBarChannel, null));

  /// Stands in for the macOS runner. Leave it unset for the platforms that
  /// have no title bar, where nothing answers the channel at all.
  void windowReports(double height) {
    messenger.setMockMethodCallHandler(
      titleBarChannel,
      (call) async => call.method == 'getHeight' ? height : null,
    );
  }

  /// Mounts the inset the way `main.dart` does, above the navigator.
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: systemInset);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => TitleBarInset(child: child!),
        home: Builder(
          builder: (context) {
            padding = MediaQuery.paddingOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> windowNowReports(WidgetTester tester, double height) async {
    await messenger.handlePlatformMessage(
      titleBarChannel.name,
      titleBarChannel.codec.encodeMethodCall(MethodCall('setHeight', height)),
      null,
    );
    await tester.pump();
  }

  testWidgets('reserves the title bar the window reports', (tester) async {
    windowReports(titleBarHeight);

    await pumpApp(tester);

    expect(padding.top, titleBarHeight);
  });

  testWidgets('reserves nothing once the window goes full screen', (
    tester,
  ) async {
    windowReports(titleBarHeight);
    await pumpApp(tester);

    await windowNowReports(tester, 0);

    expect(padding.top, systemInset);
  });

  testWidgets('takes the strip back on leaving full screen', (tester) async {
    windowReports(0);
    await pumpApp(tester);
    expect(padding.top, systemInset);

    await windowNowReports(tester, titleBarHeight);

    expect(padding.top, titleBarHeight);
  });

  testWidgets('leaves the system insets alone where nothing answers', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(padding.top, systemInset);
  });
}
