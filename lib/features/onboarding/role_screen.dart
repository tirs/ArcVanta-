import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../data/models/profile.dart';
import '../../design/components/av_brand_scaffold.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import '../../state/app_settings.dart';

class RoleScreen extends ConsumerStatefulWidget {
  const RoleScreen({super.key});

  @override
  ConsumerState<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends ConsumerState<RoleScreen> {
  AccountRole _selected = AccountRole.player;

  @override
  Widget build(BuildContext context) {
    return AvBrandScaffold(
      child: Column(
        children: [
          const AvPageHeader(
            onInk: true,
            title: 'How will you use ArcVanta?',
            subtitle:
                'This sets your default workspace. You can change it later.',
          ),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AvSpace.gutter,
                AvSpace.xs,
                AvSpace.gutter,
                AvSpace.md,
              ),
              itemCount: AccountRole.values.length,
              separatorBuilder: (_, __) => const SizedBox(height: AvSpace.sm),
              itemBuilder: (context, index) {
                final role = AccountRole.values[index];
                return _RoleCard(
                  role: role,
                  selected: role == _selected,
                  onTap: role.isAvailable
                      ? () => setState(() => _selected = role)
                      : null,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AvSpace.gutter,
              AvSpace.sm,
              AvSpace.gutter,
              AvSpace.lg,
            ),
            child: AvButton(
              label: 'Continue',
              size: AvButtonSize.large,
              expand: true,
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: () {
                ref.read(appSettingsProvider.notifier).setRole(_selected);
                context.go(AppRoute.playerSetup);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final AccountRole role;
  final bool selected;

  /// Null for roles this build cannot serve. The card still describes them so
  /// the product's shape is visible, but it will not pretend to be a choice.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final available = onTap != null;

    return AvPressable(
      onTap: onTap,
      borderRadius: AvRadius.allMd,
      child: Opacity(
        opacity: available ? 1 : 0.55,
        child: AnimatedContainer(
          duration: AvMotion.normal,
          curve: AvMotion.enter,
          padding: const EdgeInsets.all(AvSpace.md),
          decoration: BoxDecoration(
            color: selected
                ? role.color.withValues(alpha: 0.20)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: AvRadius.allMd,
            border: Border.all(
              color: selected ? role.color : AvColors.hairlineOnInk,
              width: selected ? 1.8 : 1,
            ),
            boxShadow: selected ? AvShadow.glow(role.color) : AvShadow.onInk,
          ),
          child: Row(
            children: [
              AvGlyph(
                icon: role.icon,
                color: role.color,
                size: 46,
                background: selected
                    ? role.color.withValues(alpha: 0.18)
                    : role.color.withValues(alpha: 0.10),
              ),
              const SizedBox(width: AvSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            role.label,
                            style: AvType.headingSmall.onInk,
                          ),
                        ),
                        if (!available) ...[
                          const SizedBox(width: AvSpace.xs),
                          const AvPill(
                            label: 'Soon',
                            color: AvColors.textOnInkMuted,
                            dense: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      available
                          ? role.description
                          : '${role.description} Needs an account service this '
                                'build does not include.',
                      style: AvType.bodySmall.onInkMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AvSpace.xs),
              if (available)
                AnimatedContainer(
                  duration: AvMotion.fast,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected ? role.color : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? role.color : AvColors.textOnInkMuted,
                      width: 1.8,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
