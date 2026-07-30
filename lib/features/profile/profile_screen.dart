import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../data/models/confidence.dart';
import '../../data/models/profile.dart';
import '../../design/components/av_brand.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import '../../state/app_settings.dart';
import '../../state/stores.dart';

/// Account home: who you are, how the app behaves for you, and the way out of
/// every one of those choices.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerProfileProvider);
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final entitlement = ref.watch(entitlementProvider);

    return AvScaffold(
      title: 'Profile',
      subtitle: profile.teamName,
      actions: [
        AvIconButton(
          icon: Icons.help_outline_rounded,
          tooltip: 'Help',
          onPressed: () => context.push(AppRoute.help),
        ),
      ],
      slivers: [
        SliverGutter(child: _ProfileHeader(profile: profile)),
        SliverGutter(
          top: AvSpace.sm,
          child: AvCard(
            child: Column(
              children: [
                AvKeyValue(label: 'Age band', value: profile.ageBand),
                AvKeyValue(label: 'Height', value: profile.heightLabel),
                AvKeyValue(
                  label: 'Wingspan',
                  value: '${profile.wingspanCm} cm',
                ),
                AvKeyValue(
                  label: 'Shooting hand',
                  value: profile.dominantHand.label,
                ),
                AvKeyValue(label: 'Position', value: profile.position.label),
                AvKeyValue(label: 'Level', value: profile.skillLevel.label),
                AvKeyValue(label: 'Coach', value: profile.coachName),
                if (profile.isMinor && profile.guardianName != null)
                  AvKeyValue(
                    label: 'Guardian',
                    value: profile.guardianName!,
                    trailing: const AvPill(
                      label: 'Approved',
                      color: AvColors.made,
                      dense: true,
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.sm,
          child: AvCard(
            onTap: () => context.push(AppRoute.subscription),
            child: Row(
              children: [
                AvGlyph(
                  icon: Icons.workspace_premium_rounded,
                  color: entitlement.tier.accent,
                  background: entitlement.tier.accent.withValues(alpha: 0.12),
                  size: 40,
                ),
                const SizedBox(width: AvSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entitlement.tier.label,
                        style: AvType.titleMedium.primary,
                      ),
                      Text(
                        '${entitlement.state.label} \u00B7 '
                        '${entitlement.period.label}',
                        style: AvType.caption.faint,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AvColors.textFaint,
                ),
              ],
            ),
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Coaching feedback',
            accent: AvColors.flare,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SwitchRow(
                  title: 'Spoken cues during a session',
                  detail: 'Short prompts read aloud between attempts.',
                  value: settings.spokenFeedback,
                  onChanged: (v) =>
                      controller.update((s) => s.copyWith(spokenFeedback: v)),
                ),
                _SwitchRow(
                  title: 'Haptic confirmation',
                  detail: 'A pulse on each detected make.',
                  value: settings.hapticFeedback,
                  onChanged: (v) =>
                      controller.update((s) => s.copyWith(hapticFeedback: v)),
                ),
                _SwitchRow(
                  title: 'Captions for audio coaching',
                  detail: 'Every spoken cue also appears on screen.',
                  value: settings.captionsForAudioCoaching,
                  onChanged: (v) => controller.update(
                    (s) => s.copyWith(captionsForAudioCoaching: v),
                  ),
                ),
                const SizedBox(height: AvSpace.sm),
                const AvOverline('How often'),
                const SizedBox(height: AvSpace.xs),
                AvSegmented<FeedbackFrequency>(
                  values: FeedbackFrequency.values,
                  labels: const ['Off', 'Sets', 'Few', 'Every'],
                  selected: settings.feedbackFrequency,
                  onChanged: (value) => controller.update(
                    (s) => s.copyWith(feedbackFrequency: value),
                  ),
                  dense: true,
                ),
                const SizedBox(height: AvSpace.xs),
                Text(
                  settings.feedbackFrequency.label,
                  style: AvType.caption.faint,
                ),
              ],
            ),
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Capture defaults',
            accent: AvColors.court,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AvOverline('Preferred camera angle'),
                const SizedBox(height: AvSpace.xs),
                Wrap(
                  spacing: AvSpace.xs,
                  runSpacing: AvSpace.xs,
                  children: [
                    for (final angle in CameraAngle.values)
                      AvChip(
                        label: angle.label,
                        icon: angle.icon,
                        selected: settings.preferredAngle == angle,
                        accent: AvColors.court,
                        onTap: () => controller.setPreferredAngle(angle),
                      ),
                  ],
                ),
                const SizedBox(height: AvSpace.md),
                _SwitchRow(
                  title: 'Show analysis overlays',
                  detail:
                      'Skeleton, arc trace and tracked boxes on the live '
                      'preview.',
                  value: settings.showOverlays,
                  onChanged: (v) =>
                      controller.update((s) => s.copyWith(showOverlays: v)),
                ),
                if (settings.showOverlays) ...[
                  _SwitchRow(
                    title: 'Skeleton',
                    detail: 'Body landmarks and joint angles.',
                    inset: true,
                    value: settings.showSkeleton,
                    onChanged: (v) =>
                        controller.update((s) => s.copyWith(showSkeleton: v)),
                  ),
                  _SwitchRow(
                    title: 'Arc trace',
                    detail: 'Ball path from release to the rim.',
                    inset: true,
                    value: settings.showTrajectory,
                    onChanged: (v) =>
                        controller.update((s) => s.copyWith(showTrajectory: v)),
                  ),
                  _SwitchRow(
                    title: 'Tracked boxes',
                    detail: 'Detection boxes for rim, ball and player.',
                    inset: true,
                    value: settings.showZones,
                    onChanged: (v) =>
                        controller.update((s) => s.copyWith(showZones: v)),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Accessibility',
            accent: AvColors.insight,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              children: [
                _SwitchRow(
                  title: 'High contrast',
                  detail: 'Stronger separation between surfaces and text.',
                  value: settings.highContrast,
                  onChanged: (v) =>
                      controller.update((s) => s.copyWith(highContrast: v)),
                ),
                _SwitchRow(
                  title: 'Larger text',
                  detail: 'Increases type size across the app.',
                  value: settings.largeText,
                  onChanged: (v) =>
                      controller.update((s) => s.copyWith(largeText: v)),
                ),
                _SwitchRow(
                  title: 'Reduce motion',
                  detail: 'Removes transitions and animated overlays.',
                  value: settings.reducedMotion,
                  onChanged: (v) =>
                      controller.update((s) => s.copyWith(reducedMotion: v)),
                ),
                _SwitchRow(
                  title: 'Left-handed layout',
                  detail: 'Moves live controls to the reachable side.',
                  value: settings.leftHandedLayout,
                  onChanged: (v) =>
                      controller.update((s) => s.copyWith(leftHandedLayout: v)),
                ),
              ],
            ),
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Account',
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AvSpace.md,
              vertical: AvSpace.xs,
            ),
            child: Column(
              children: [
                _NavRow(
                  icon: Icons.shield_rounded,
                  label: 'Privacy and data',
                  detail: 'Processing, retention, sharing and deletion',
                  onTap: () => context.push(AppRoute.privacy),
                ),
                _NavRow(
                  icon: Icons.phone_iphone_rounded,
                  label: 'Device and capture',
                  detail: 'Frame rate, thermal guard, storage budget',
                  onTap: () => context.push(AppRoute.device),
                ),
                _NavRow(
                  icon: Icons.notifications_rounded,
                  label: 'Notifications',
                  detail: 'What reaches you and when',
                  onTap: () => context.push(AppRoute.notifications),
                ),
                _NavRow(
                  icon: Icons.movie_creation_rounded,
                  label: 'Highlights',
                  detail: 'Saved reels and who can see them',
                  onTap: () => context.push(AppRoute.highlights),
                ),
                _NavRow(
                  icon: Icons.history_rounded,
                  label: 'Session history',
                  detail: 'Everything recorded on this device',
                  onTap: () => context.push(AppRoute.sessions),
                ),
                _NavRow(
                  icon: Icons.help_center_rounded,
                  label: 'Help and support',
                  detail: 'Setup guides, accuracy notes, contact',
                  onTap: () => context.push(AppRoute.help),
                ),
              ],
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.lg,
          child: AvButton(
            label: 'Sign out',
            variant: AvButtonVariant.outline,
            icon: Icons.logout_rounded,
            expand: true,
            onPressed: () => _confirmSignOut(context, ref),
          ),
        ),
        SliverGutter(
          top: AvSpace.md,
          child: Center(
            child: Column(
              children: [
                const AvBrandLockup(markSize: 28, fontSize: 15),
                const SizedBox(height: AvSpace.xs),
                Text(
                  'Version 1.0.0 \u00B7 build 100',
                  style: AvType.caption.faint,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text(
          'Sessions stored on this device stay on this device. You will need '
          'to sign in again to sync with your coach.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(appSettingsProvider.notifier).reset();
              Navigator.of(context).pop();
              context.go(AppRoute.splash);
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    return AvInkCard(
      padding: const EdgeInsets.all(AvSpace.lg),
      accent: profile.accentColor,
      child: Row(
        children: [
          AvAvatar(
            initials: profile.initials,
            color: profile.accentColor,
            size: 64,
            ring: true,
          ),
          const SizedBox(width: AvSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: AvType.headingMedium.copyWith(
                    color: AvColors.textOnInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${profile.position.label} \u00B7 ${profile.skillLevel.label}',
                  style: AvType.caption.copyWith(
                    color: AvColors.textOnInkMuted,
                  ),
                ),
                const SizedBox(height: AvSpace.sm),
                Wrap(
                  spacing: AvSpace.xxs,
                  runSpacing: AvSpace.xxs,
                  children: [
                    for (final goal in profile.goals.take(2))
                      AvPill(
                        label: goal,
                        color: AvColors.textOnInkMuted,
                        dense: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.detail,
    required this.value,
    required this.onChanged,
    this.inset = false,
  });

  final String title;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: inset ? AvSpace.md : 0, top: 2, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: inset
                      ? AvType.titleSmall.muted
                      : AvType.titleSmall.primary,
                ),
                Text(detail, style: AvType.caption.faint),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AvPressable(
      onTap: onTap,
      borderRadius: AvRadius.allSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AvSpace.sm),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AvColors.textSecondary),
            const SizedBox(width: AvSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AvType.titleSmall.primary),
                  Text(detail, style: AvType.caption.faint),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AvColors.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}
