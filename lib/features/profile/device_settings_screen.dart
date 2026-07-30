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

/// Capture and storage controls. Real-time vision work is the most demanding
/// thing a phone does, so the trade-offs are exposed rather than hidden behind
/// an automatic quality setting.
class DeviceSettingsScreen extends ConsumerWidget {
  const DeviceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final sessions = ref.watch(sessionStoreProvider);

    final usedGb = sessions.length * 0.62;
    final usedFraction =
        (usedGb / settings.storageBudgetGb).clamp(0.0, 1.0).toDouble();

    return AvScaffold(
      title: 'Device and capture',
      subtitle: 'Performance, thermals and storage',
      leading: const AvBackButton(),
      slivers: [
        SliverGutter(
          child: AvCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const AvGlyph(
                      icon: Icons.phone_iphone_rounded,
                      color: AvColors.court,
                      background: AvColors.courtSoft,
                      size: 42,
                    ),
                    const SizedBox(width: AvSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'iPhone 17 Pro',
                            style: AvType.titleMedium.primary,
                          ),
                          Text(
                            'Neural engine capture profile \u00B7 60 fps '
                            'supported',
                            style: AvType.caption.faint,
                          ),
                        ],
                      ),
                    ),
                    const AvPill(
                      label: 'Full support',
                      color: AvColors.made,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: AvSpace.md),
                const AvSeparator(),
                const SizedBox(height: AvSpace.sm),
                const AvKeyValue(label: 'Detection model', value: 'det-1.4.2'),
                const AvKeyValue(label: 'Pose model', value: 'pose-2.1.0'),
                const AvKeyValue(label: 'Event model', value: 'event-3.0.1'),
                const AvKeyValue(
                  label: 'Typical processing',
                  value: '28 to 31 fps',
                ),
              ],
            ),
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Capture quality',
            accent: AvColors.flare,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              children: [
                _SettingSwitch(
                  title: 'High frame rate capture',
                  detail: 'Records at 60 fps. Sharper release timing and '
                      'better arc, at roughly twice the storage and more heat.',
                  value: settings.highFrameRateCapture,
                  onChanged: (v) => controller.update(
                    (s) => s.copyWith(highFrameRateCapture: v),
                  ),
                ),
                _SettingSwitch(
                  title: 'Thermal guard',
                  detail: 'Drops overlay detail before it drops measurement '
                      'quality when the phone gets hot.',
                  value: settings.thermalGuard,
                  onChanged: (v) =>
                      controller.update((s) => s.copyWith(thermalGuard: v)),
                ),
              ],
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.sm,
          child: AvTintCard(
            tint: AvColors.cautionSoft,
            borderColor: AvColors.caution,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 18,
                  color: AvColors.cautionDeep,
                ),
                const SizedBox(width: AvSpace.sm),
                Expanded(
                  child: Text(
                    settings.thermalGuard
                        ? 'With the guard on, a long session in a warm gym '
                            'will simplify the overlay rather than lower '
                            'tracking accuracy.'
                        : 'With the guard off, sustained capture may throttle '
                            'the processing rate, which lowers confidence on '
                            'release timing.',
                    style: AvType.caption.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Storage',
            accent: AvColors.insight,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      usedGb.toStringAsFixed(1),
                      style: AvType.tabular(AvType.metricLarge)
                          .copyWith(fontSize: 30, color: AvColors.insight),
                    ),
                    Text(' GB used', style: AvType.caption.muted),
                    const Spacer(),
                    Text(
                      'of ${settings.storageBudgetGb} GB budget',
                      style: AvType.tabular(AvType.caption).faint,
                    ),
                  ],
                ),
                const SizedBox(height: AvSpace.sm),
                AvMeter(
                  value: usedFraction,
                  color: usedFraction > 0.85
                      ? AvColors.caution
                      : AvColors.insight,
                ),
                const SizedBox(height: AvSpace.md),
                const AvOverline('Budget'),
                Slider(
                  value: settings.storageBudgetGb.toDouble(),
                  min: 2,
                  max: 64,
                  divisions: 31,
                  label: '${settings.storageBudgetGb} GB',
                  onChanged: (value) => controller.update(
                    (s) => s.copyWith(storageBudgetGb: value.round()),
                  ),
                ),
                Text(
                  'When the budget is reached, the oldest video is removed '
                  'first. Measurements are never deleted to free space.',
                  style: AvType.caption.faint,
                ),
                const SizedBox(height: AvSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: AvButton(
                        label: 'Clear cache',
                        variant: AvButtonVariant.outline,
                        size: AvButtonSize.small,
                        expand: true,
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Temporary analysis files removed'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AvSpace.xs),
                    Expanded(
                      child: AvButton(
                        label: 'Free up video',
                        variant: AvButtonVariant.tonal,
                        size: AvButtonSize.small,
                        expand: true,
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Removing clips older than your retention window',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Permissions',
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              children: const [
                _PermissionRow(
                  icon: Icons.videocam_rounded,
                  label: 'Camera',
                  state: 'Allowed',
                  detail: 'Required. Without it nothing can be measured.',
                  granted: true,
                ),
                AvSeparator(inset: 34),
                _PermissionRow(
                  icon: Icons.mic_rounded,
                  label: 'Microphone',
                  state: 'Not used',
                  detail: 'Audio is never recorded with your sessions.',
                  granted: false,
                ),
                AvSeparator(inset: 34),
                _PermissionRow(
                  icon: Icons.photo_library_rounded,
                  label: 'Photo library',
                  state: 'Ask each time',
                  detail: 'Only used when you export a highlight.',
                  granted: true,
                ),
                AvSeparator(inset: 34),
                _PermissionRow(
                  icon: Icons.notifications_rounded,
                  label: 'Notifications',
                  state: 'Allowed',
                  detail: 'Reminders and coach assignments.',
                  granted: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
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

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.label,
    required this.state,
    required this.detail,
    required this.granted,
  });

  final IconData icon;
  final String label;
  final String state;
  final String detail;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AvSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: granted ? AvColors.court : AvColors.textFaint,
          ),
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
          const SizedBox(width: AvSpace.xs),
          AvPill(
            label: state,
            color: granted ? AvColors.made : AvColors.unavailable,
            dense: true,
          ),
        ],
      ),
    );
  }
}
