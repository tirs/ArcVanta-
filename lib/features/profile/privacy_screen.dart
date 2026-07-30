import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import '../../state/app_settings.dart';
import '../../state/stores.dart';

/// Privacy controls stated as decisions rather than legal text: what leaves the
/// device, how long it is kept, who can see it, and how to end all of it.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final profile = ref.watch(playerProfileProvider);

    return AvScaffold(
      title: 'Privacy and data',
      subtitle: 'What leaves this device, and when',
      leading: const AvBackButton(),
      slivers: [
        SliverGutter(
          child: AvInkCard(
            padding: const EdgeInsets.all(AvSpace.lg),
            accent: AvColors.court,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AvGlyph(
                  icon: Icons.phonelink_lock_rounded,
                  color: AvColors.court,
                  background: Color(0x2200A6C0),
                  size: 46,
                ),
                const SizedBox(width: AvSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.localProcessingOnly
                            ? 'Everything is processed on this device'
                            : 'Some analysis runs in the cloud',
                        style: AvType.headingSmall
                            .copyWith(color: AvColors.textOnInk),
                      ),
                      const SizedBox(height: AvSpace.xs),
                      Text(
                        settings.localProcessingOnly
                            ? 'Video never leaves the phone. Detection, pose '
                                'and shot events all run locally.'
                            : 'Selected clips are uploaded for deeper '
                                'analysis and deleted after processing.',
                        style: AvType.bodySmall
                            .copyWith(color: AvColors.textOnInkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Processing',
            accent: AvColors.court,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              children: [
                _ConsentRow(
                  title: 'Process on device only',
                  detail: 'Turning this off allows selected clips to be sent '
                      'for cloud analysis, one clip at a time, with a prompt '
                      'each time.',
                  value: settings.localProcessingOnly,
                  onChanged: (v) => controller.update(
                    (s) => s.copyWith(localProcessingOnly: v),
                  ),
                ),
                _ConsentRow(
                  title: 'Back up sessions',
                  detail: 'Encrypted copies of measurements and summaries. '
                      'Video is never included in backups.',
                  value: settings.cloudBackup,
                  onChanged: (v) =>
                      controller.update((s) => s.copyWith(cloudBackup: v)),
                ),
                _ConsentRow(
                  title: 'Help improve detection',
                  detail: 'Shares corrected results, never video and never '
                      'anything that identifies you. Off by default.',
                  value: settings.modelTrainingConsent,
                  onChanged: (v) => controller.update(
                    (s) => s.copyWith(modelTrainingConsent: v),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'How long recordings are kept',
            accent: AvColors.insight,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AvSegmented<RetentionWindow>(
                  values: RetentionWindow.values,
                  labels: [
                    for (final window in RetentionWindow.values) window.label,
                  ],
                  selected: settings.retention,
                  accent: AvColors.insight,
                  onChanged: (value) =>
                      controller.update((s) => s.copyWith(retention: value)),
                  dense: true,
                ),
                const SizedBox(height: AvSpace.sm),
                Text(
                  settings.retention == RetentionWindow.untilDeleted
                      ? 'Video stays on the device until you delete it. '
                          'Measurements are always kept.'
                      : 'Video is deleted automatically after '
                          '${settings.retention.label.toLowerCase()}. '
                          'Measurements and summaries are kept.',
                  style: AvType.caption.muted,
                ),
              ],
            ),
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Who can see your work',
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              children: [
                AvKeyValue(
                  label: 'Coach',
                  value: profile.coachName,
                  trailing: const AvPill(
                    label: 'Summaries and clips you send',
                    color: AvColors.court,
                    dense: true,
                  ),
                ),
                if (profile.isMinor && profile.guardianName != null)
                  AvKeyValue(
                    label: 'Guardian',
                    value: profile.guardianName!,
                    trailing: const AvPill(
                      label: 'Full access',
                      color: AvColors.made,
                      dense: true,
                    ),
                  ),
                const AvKeyValue(
                  label: 'Team',
                  value: 'Nothing shared',
                  trailing: AvPill(
                    label: 'Off',
                    color: AvColors.unavailable,
                    dense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (profile.isMinor)
          SliverGutter(
            top: AvSpace.sm,
            child: AvTintCard(
              tint: AvColors.cautionSoft,
              borderColor: AvColors.caution,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AvGlyph(
                    icon: Icons.family_restroom_rounded,
                    color: AvColors.cautionDeep,
                    background: AvColors.cautionSoft,
                    size: 36,
                  ),
                  const SizedBox(width: AvSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This is a minor account',
                          style: AvType.titleSmall.primary,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Cloud processing, team visibility and any purchase '
                          'require guardian approval. Public sharing is not '
                          'available at all.',
                          style: AvType.caption.muted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Your data',
            accent: AvColors.miss,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              children: [
                AvButton(
                  label: 'Export everything',
                  variant: AvButtonVariant.outline,
                  icon: Icons.download_rounded,
                  expand: true,
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Preparing a full export of sessions and measurements',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AvSpace.xs),
                AvButton(
                  label: 'Delete all video',
                  variant: AvButtonVariant.outline,
                  icon: Icons.videocam_off_rounded,
                  expand: true,
                  onPressed: () => _confirm(
                    context,
                    title: 'Delete all video',
                    body: 'Clips on this device are removed permanently. '
                        'Measurements, sessions and trends are kept.',
                    action: 'Delete video',
                  ),
                ),
                const SizedBox(height: AvSpace.xs),
                AvButton(
                  label: 'Delete my account',
                  variant: AvButtonVariant.danger,
                  icon: Icons.delete_forever_rounded,
                  expand: true,
                  onPressed: () => _confirm(
                    context,
                    title: 'Delete your account',
                    body: 'Every session, measurement, clip and setting is '
                        'erased from this device and from backup within '
                        'thirty days. This cannot be undone.',
                    action: 'Delete account',
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.md,
          child: AvTintCard(
            tint: AvColors.canvasSunken,
            child: Text(
              'Measurements are estimates from video, not medical or clinical '
              'data. They are never used to make decisions about you without '
              'a human in the loop, and they are never sold.',
              style: AvType.caption.muted,
            ),
          ),
        ),
      ],
    );
  }

  void _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: AvColors.critical),
            child: Text(action),
          ),
        ],
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.title,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AvSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AvType.titleSmall.primary),
                const SizedBox(height: 2),
                Text(detail, style: AvType.caption.muted),
              ],
            ),
          ),
          const SizedBox(width: AvSpace.sm),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
