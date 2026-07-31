import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/device_identity.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../core/utils/formatters.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import '../../data/capture/native_capture_source.dart';
import '../../state/app_settings.dart';
import '../../state/capture_pipeline.dart';
import '../../state/bootstrap.dart';
import '../../state/stores.dart';

/// Capture and storage controls. Real-time vision work is the most demanding
/// thing a phone does, so the trade-offs are exposed rather than hidden behind
/// an automatic quality setting.
class DeviceSettingsScreen extends ConsumerWidget {
  const DeviceSettingsScreen({super.key});

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final sessions = ref.watch(sessionStoreProvider);
    final storedBytes = ref.watch(storageBytesProvider);
    final pipeline = ref.watch(pipelineStatusProvider).valueOrNull;
    final live = pipeline?.isLive ?? false;
    final lastRate = sessions.isEmpty
        ? null
        : sessions.first.calibration.frameRate;

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
                            DeviceIdentity.name,
                            style: AvType.titleMedium.primary,
                          ),
                          Text(
                            pipeline?.explanation ?? 'Checking the pipeline',
                            style: AvType.caption.faint,
                          ),
                        ],
                      ),
                    ),
                    AvPill(
                      label: live ? 'Measuring' : 'Simulated',
                      color: live ? AvColors.made : AvColors.caution,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: AvSpace.md),
                const AvSeparator(),
                const SizedBox(height: AvSpace.sm),
                AvKeyValue(
                  label: 'Analysis models',
                  value: pipeline?.runtime?.signature ?? 'Not installed',
                ),
                AvKeyValue(
                  label: 'Last capture rate',
                  value: lastRate == null ? 'No sessions yet' : '$lastRate fps',
                ),
              ],
            ),
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Court',
            accent: AvColors.court,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CourtNameField(
                  initial: settings.courtName,
                  onChanged: (value) =>
                      controller.update((s) => s.copyWith(courtName: value)),
                ),
                const SizedBox(height: AvSpace.xs),
                Text(
                  'Stamped on every session recorded here, so results from the '
                  'gym and the driveway stay tellable apart.',
                  style: AvType.caption.faint,
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
                  detail:
                      'Measures at 60 fps. Sharper release timing and better '
                      'arc, at twice the work per second and more heat.',
                  value: settings.highFrameRateCapture,
                  onChanged: (v) => controller.update(
                    (s) => s.copyWith(highFrameRateCapture: v),
                  ),
                ),
                _SettingSwitch(
                  title: 'Thermal guard',
                  detail:
                      'Drops overlay detail before it drops measurement '
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
                    Flexible(
                      child: FittedBox(
                        child: Text(
                          switch (storedBytes) {
                            AsyncData(:final value) => _formatBytes(value),
                            AsyncError() => '—',
                            _ => '…',
                          },
                          style: AvType.tabular(
                            AvType.metricLarge,
                          ).copyWith(fontSize: 30, color: AvColors.insight),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${Fmt.count(sessions.length, 'session')}, '
                      '${Fmt.count(sessions.fold(0, (n, s) => n + s.shots.length), 'shot')}',
                      style: AvType.tabular(AvType.caption).faint,
                    ),
                  ],
                ),
                const SizedBox(height: AvSpace.xs),
                Text(
                  'Measurements and summaries are stored as structured data, '
                  'not video, which is why a full season takes so little '
                  'room. Removing it all is under Privacy and data.',
                  style: AvType.caption.faint,
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
              children: [
                _PermissionRow(
                  icon: Icons.videocam_rounded,
                  label: 'Camera',
                  state: switch (pipeline?.fallbackReason) {
                    null => live ? 'Allowed' : 'Checking',
                    CaptureUnavailableReason.cameraPermissionDenied => 'Denied',
                    _ => 'Allowed',
                  },
                  detail: 'Required. Without it nothing can be measured.',
                  granted:
                      pipeline?.fallbackReason !=
                      CaptureUnavailableReason.cameraPermissionDenied,
                ),
                const AvSeparator(inset: 34),
                const _PermissionRow(
                  icon: Icons.mic_rounded,
                  label: 'Microphone',
                  state: 'Not used',
                  detail: 'Audio is never recorded with your sessions.',
                  granted: false,
                ),
                const AvSeparator(inset: 34),
                const _PermissionRow(
                  icon: Icons.photo_library_rounded,
                  label: 'Photo library',
                  state: 'Not used',
                  detail: 'No video or image is written to your library.',
                  granted: false,
                ),
                const AvSeparator(inset: 34),
                const _PermissionRow(
                  icon: Icons.notifications_rounded,
                  label: 'System notifications',
                  state: 'Not used',
                  detail:
                      'Alerts appear inside the app only. Nothing is scheduled '
                      'against the system tray.',
                  granted: false,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Names the venue, writing through on every keystroke.
///
/// Stateful only to own the controller: rebuilding the field from settings on
/// each change would move the caret to the end mid-word.
class _CourtNameField extends StatefulWidget {
  const _CourtNameField({required this.initial, required this.onChanged});

  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_CourtNameField> createState() => _CourtNameFieldState();
}

class _CourtNameFieldState extends State<_CourtNameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textCapitalization: TextCapitalization.words,
      onChanged: widget.onChanged,
      decoration: const InputDecoration(
        labelText: 'Where you shoot',
        hintText: 'Main gym, driveway, park court',
      ),
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
