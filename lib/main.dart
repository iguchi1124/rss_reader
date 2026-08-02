import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/core/theme.dart';
import 'ui/core/title_bar_inset.dart';
import 'ui/features/home/views/home_screen.dart';

void main() {
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
