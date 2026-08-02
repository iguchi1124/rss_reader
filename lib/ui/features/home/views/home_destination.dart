import 'package:flutter/material.dart';

/// One tab, described once so the phone bar and the desktop sidebar cannot
/// drift apart on labels or icons.
class HomeDestination {
  const HomeDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const homeDestinations = [
  HomeDestination(
    label: 'Latest',
    icon: Icons.article_outlined,
    selectedIcon: Icons.article,
  ),
  HomeDestination(
    label: 'Feeds',
    icon: Icons.rss_feed_outlined,
    selectedIcon: Icons.rss_feed,
  ),
];
