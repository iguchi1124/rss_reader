import 'package:flutter/material.dart';

import '../../../core/widgets/glass_surface.dart';
import 'home_destination.dart';

/// Height of the capsule itself, without the gap or the safe area below it.
const double homeNavigationBarHeight = 56;

const double _sideInset = 16;
const double _bottomGap = 12;

/// The tab bar on phones: a capsule floating over the content rather than a
/// band beneath it. Pair it with `Scaffold.extendBody` — a panel with nothing
/// passing behind it is only a tinted rectangle.
class HomeNavigationBar extends StatelessWidget {
  const HomeNavigationBar({
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _sideInset,
        0,
        _sideInset,
        _bottomGap + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: GlassSurface(
        // Half the height is the pill the design language asks for.
        borderRadius: homeNavigationBarHeight / 2,
        border: Border.fromBorderSide(glassEdge(context)),
        child: Material(
          type: MaterialType.transparency,
          child: SizedBox(
            height: homeNavigationBarHeight,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  for (final (index, destination)
                      in homeDestinations.indexed) ...[
                    if (index > 0) const SizedBox(width: 4),
                    Expanded(
                      child: _Destination(
                        destination: destination,
                        selected: index == selectedIndex,
                        unreadCount: index == 0 ? unreadCount : 0,
                        onTap: () => onDestinationSelected(index),
                      ),
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

class _Destination extends StatelessWidget {
  const _Destination({
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
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? colorScheme.secondaryContainer : null,
            borderRadius: const BorderRadius.all(Radius.circular(22)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge.count(
                count: unreadCount,
                isLabelVisible: unreadCount > 0,
                child: Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 20,
                  color: foreground,
                ),
              ),
              Text(
                destination.label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
