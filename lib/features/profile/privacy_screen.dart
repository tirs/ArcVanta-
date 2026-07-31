import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../data/store/export.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import '../../state/app_settings.dart';
import '../../state/bootstrap.dart';
import '../../state/cloud.dart';
import '../../state/demo_mode.dart';
import '../../state/stores.dart';

/// Privacy controls stated as decisions rather than legal text: what leaves the
/// device, how long it is kept, who can see it, and how to end all of it.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
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
                        'Everything is processed on this device',
                        style: AvType.headingSmall.copyWith(
                          color: AvColors.textOnInk,
                        ),
                      ),
                      const SizedBox(height: AvSpace.xs),
                      Text(
                        'No video is written at all. Detection, pose and shot '
                        'events are measured here and stay here, because '
                        'there is nowhere configured to send them.',
                        style: AvType.bodySmall.copyWith(
                          color: AvColors.textOnInkMuted,
                        ),
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
                const _ConsentRow(
                  title: 'Process on device only',
                  detail:
                      'Detection, pose and shot measurement all run on this '
                      'phone. There is no cloud path to turn on.',
                  value: true,
                  onChanged: null,
                ),
                const _ConsentRow(
                  title: 'Back up sessions',
                  detail:
                      'Copies of measurements and summaries held off the '
                      'device. ${CloudFeatures.unavailableRowNote}',
                  value: false,
                  onChanged: null,
                ),
                const _ConsentRow(
                  title: 'Help improve detection',
                  detail:
                      'Sharing corrected results to train better models. '
                      '${CloudFeatures.unavailableRowNote}',
                  value: false,
                  onChanged: null,
                ),
              ],
            ),
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'What is kept',
            accent: AvColors.insight,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sessions are stored as measurements: shot positions, '
                  'angles, timings and summaries. No video file is written, '
                  'so there is nothing to expire and no retention window to '
                  'choose. Frames are read from the camera, measured, and '
                  'discarded within the same session.',
                  style: AvType.bodySmall.muted,
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
                const AvKeyValue(
                  label: 'Coach',
                  value: 'Nothing shared',
                  trailing: AvPill(
                    label: 'Not built',
                    color: AvColors.unavailable,
                    dense: true,
                  ),
                ),
                const AvKeyValue(
                  label: 'Team',
                  value: 'Nothing shared',
                  trailing: AvPill(
                    label: 'Not built',
                    color: AvColors.unavailable,
                    dense: true,
                  ),
                ),
                if (profile.isMinor && profile.guardianName != null)
                  AvKeyValue(
                    label: 'Guardian on record',
                    value: profile.guardianName!,
                  ),
                const SizedBox(height: AvSpace.xs),
                Text(
                  'Sharing needs an account service this build does not '
                  'include, so no path off this phone exists to switch on.',
                  style: AvType.caption.faint,
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
                          'Team visibility and purchases would require '
                          'guardian approval. Neither is available in this '
                          'build, and public sharing never will be.',
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
                  onPressed: () => _export(context, ref),
                ),
                const SizedBox(height: AvSpace.xs),
                AvButton(
                  label: 'Delete everything',
                  variant: AvButtonVariant.danger,
                  icon: Icons.delete_forever_rounded,
                  expand: true,
                  onPressed: () => _confirm(
                    context,
                    title: 'Delete everything',
                    body:
                        'Every session, shot, measurement, goal and setting '
                        'is erased from this device. Nothing is kept '
                        'anywhere else, so this cannot be undone.',
                    action: 'Delete everything',
                    onConfirm: () => _deleteEverything(context, ref),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Sample data',
            accent: AvColors.caution,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: _ConsentRow(
              title: 'Show a sample season',
              detail: settings.demoDataEnabled
                  ? 'A fabricated history is loaded so you can see how the '
                        'charts behave. It is marked everywhere it appears '
                        'and is never counted with your own shooting.'
                  : 'Loads a fabricated history so you can explore the '
                        'charts before you have shot anything. Clearly '
                        'labelled, and kept apart from your real sessions.',
              value: settings.demoDataEnabled,
              onChanged: (value) =>
                  ref.read(demoModeProvider).setEnabled(value),
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.md,
          child: AvTintCard(
            tint: AvColors.canvasSunken,
            child: Text(
              'Measurements are camera estimates, not medical or clinical '
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
    VoidCallback? onConfirm,
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
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm?.call();
            },
            style: TextButton.styleFrom(foregroundColor: AvColors.critical),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  /// Hands the athlete a file containing everything the app holds on them.
  ///
  /// Written to a temporary file and passed to the system share sheet, so the
  /// destination is their choice rather than ours — which is the whole point
  /// of an export on a device that talks to no server.
  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final payload = DataExport.build(
      sessions: ref.read(sessionStoreProvider),
      profile: ref.read(profileStoreProvider),
      goals: ref.read(goalStoreProvider),
      highlights: ref.read(highlightStoreProvider),
      exportedAt: now,
    );

    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/${DataExport.fileName(now)}');
      await file.writeAsString(payload);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'ArcVanta AI export',
        ),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not write the export: $error')),
      );
    }
  }

  Future<void> _deleteEverything(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(repositoryProvider).deleteEverything();

    ref.read(sessionStoreProvider.notifier).clear();
    ref.read(goalStoreProvider.notifier).clear();
    ref.read(highlightStoreProvider.notifier).clear();
    ref.read(notificationStoreProvider.notifier).clear();
    ref.read(profileStoreProvider.notifier).clear();
    ref.read(appSettingsProvider.notifier).reset();

    messenger.showSnackBar(
      const SnackBar(content: Text('Everything on this device was deleted')),
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

  /// A null handler means the setting is not a choice in this build. The row
  /// still states where the app stands, but shows a fixed marker rather than a
  /// switch, so nobody flips something that cannot move.
  final ValueChanged<bool>? onChanged;

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
          if (onChanged case final handler?)
            Switch(value: value, onChanged: handler)
          else
            AvPill(
              label: value ? 'Always on' : 'Not available',
              color: value ? AvColors.made : AvColors.textMuted,
            ),
        ],
      ),
    );
  }
}
