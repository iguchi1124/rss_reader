import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'ui/core/theme.dart';
import 'ui/core/title_bar_inset.dart';
import 'ui/features/home/views/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Compiles the glass shaders before the first frame. Skipping it is not an
  // error — they load on first paint instead — but the tab bar then draws
  // unfrosted for a frame or two on a cold start.
  await LiquidGlassWidgets.initialize();
  runApp(const ProviderScope(child: RssReaderApp()));
}

class RssReaderApp extends StatelessWidget {
  const RssReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RSS Reader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Above the navigator, so a pushed route clears the title bar too.
      builder: (context, child) => TitleBarInset(child: child!),
      home: const HomeScreen(),
    );
  }
}
