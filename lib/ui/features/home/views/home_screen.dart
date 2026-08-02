import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../articles/views/article_list_screen.dart';
import '../../feeds/view_models/feed_list_view_model.dart';
import '../../feeds/views/feed_list_screen.dart';
import 'home_navigation_bar.dart';
import 'home_sidebar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    // Watched here rather than inside a tab so the badge survives switching.
    final unread = ref.watch(unreadCountProvider);

    // Read from the theme rather than dart:io so an override reaches it and
    // a test can render both arrangements.
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;

    // Keeps scroll position and already-loaded articles across tab switches.
    final body = IndexedStack(
      index: _index,
      children: const [ArticleListScreen(), FeedListScreen()],
    );

    if (isMac) {
      return Scaffold(
        body: Row(
          children: [
            HomeSidebar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              unreadCount: unread,
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      // The tab bar is translucent, so the list has to run behind it. This
      // also hands the bar's height to the body as MediaQuery bottom padding.
      extendBody: true,
      body: body,
      bottomNavigationBar: HomeNavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        unreadCount: unread,
      ),
    );
  }
}
