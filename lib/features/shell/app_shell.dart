import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../design/components/av_surface.dart';
import '../../state/app_settings.dart';
import '../../state/stores.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    final destinations = <_Destination>[
      const _Destination(
        label: 'Home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        accent: AvColors.flare,
      ),
      const _Destination(
        label: 'Train',
        icon: Icons.sports_basketball_outlined,
        activeIcon: Icons.sports_basketball_rounded,
        accent: AvColors.court,
      ),
      const _Destination(
        label: 'Progress',
        icon: Icons.insights_outlined,
        activeIcon: Icons.insights_rounded,
        accent: AvColors.insight,
      ),
      _Destination(
        label: settings.isCoachRole ? 'Roster' : 'Coach',
        icon: Icons.groups_outlined,
        activeIcon: Icons.groups_rounded,
        accent: AvColors.made,
        badge: settings.isCoachRole ? unread : 0,
      ),
      const _Destination(
        label: 'Profile',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        accent: AvColors.caution,
      ),
    ];

    return Scaffold(
      backgroundColor: AvColors.canvas,
      extendBody: true,
      body: shell,
      bottomNavigationBar: _NavBar(
        destinations: destinations,
        currentIndex: shell.currentIndex,
        onSelect: (index) => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.accent,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Color accent;
  final int badge;
}

/// Floating ink navigation bar. The dark bar reads clearly against the warm
/// canvas and keeps the active accent colour tied to each area of the product.
class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<_Destination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AvSpace.md,
        0,
        AvSpace.md,
        bottomInset > 0 ? bottomInset * 0.5 + 6 : AvSpace.sm,
      ),
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          gradient: AvGradients.ink,
          borderRadius: AvRadius.pill,
          boxShadow: AvShadow.onInk,
          border: Border.all(color: AvColors.inkHairline),
        ),
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: _NavItem(
                  destination: destinations[i],
                  selected: i == currentIndex,
                  onTap: () => onSelect(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? destination.accent : AvColors.textOnInkMuted;

    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: AvPressable(
        onTap: onTap,
        borderRadius: AvRadius.pill,
        scale: 0.94,
        child: Container(
          height: double.infinity,
          alignment: Alignment.center,
          color: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: AvMotion.normal,
                    curve: AvMotion.emphasized,
                    padding: EdgeInsets.symmetric(
                      horizontal: selected ? 14 : 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? destination.accent.withValues(alpha: 0.18)
                          : Colors.transparent,
                      borderRadius: AvRadius.pill,
                    ),
                    child: Icon(
                      selected ? destination.activeIcon : destination.icon,
                      size: 21,
                      color: color,
                    ),
                  ),
                  if (destination.badge > 0)
                    Positioned(
                      right: 2,
                      top: -1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AvColors.flare,
                          shape: BoxShape.circle,
                          border: Border.all(color: AvColors.ink, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: AvMotion.normal,
                style: AvType.overline.copyWith(
                  color: color,
                  letterSpacing: 0.3,
                  fontSize: 9.5,
                ),
                child: Text(destination.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
