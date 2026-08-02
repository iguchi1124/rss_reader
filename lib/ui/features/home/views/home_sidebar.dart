import 'package:flutter/material.dart';

import '../../../core/widgets/glass_surface.dart';
import 'home_destination.dart';

const double homeSidebarWidth = 220;

/// Navigation on macOS, where a bottom tab bar is not the platform's idiom.
///
/// The blur here has less to work on than the phone bar does: macOS vibrancy
/// samples the desktop behind the window, which Flutter cannot reach without
/// an `NSVisualEffectView`. What it blurs is the window background, so the
/// panel reads as translucent rather than as true vibrancy.
class HomeSidebar extends StatelessWidget {
  const HomeSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.unreadCount,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: homeSidebarWidth,
      child: GlassSurface(
        border: Border(right: glassEdge(context)),
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            right: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, destination)
                      in homeDestinations.indexed) ...[
                    if (index > 0) const SizedBox(height: 4),
                    _SidebarItem(
                      destination: destination,
                      selected: index == selectedIndex,
                      unreadCount: index == 0 ? unreadCount : 0,
                      onTap: () => onDestinationSelected(index),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.unreadCount,
    required this.onTap,
  });

  final HomeDestination destination;
  final bool selected;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: Ink(
          height: 40,
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.secondaryContainer : null,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 20,
                  color: selected
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
                if (unreadCount > 0)
                  Badge.count(count: unreadCount, largeSize: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
