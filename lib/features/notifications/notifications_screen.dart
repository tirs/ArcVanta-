import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/program.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import '../../state/app_settings.dart';
import '../../state/stores.dart';

/// Inbox plus the controls that govern it. Notification settings sit on the
/// same screen as the messages so turning something off never requires
/// hunting through preferences.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _showSettings = false;

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationStoreProvider);
    final unread = notifications.where((n) => !n.read).length;

    return AvScaffold(
      title: 'Notifications',
      subtitle: unread == 0 ? 'All caught up' : '$unread unread',
      leading: const AvBackButton(),
      actions: [
        AvIconButton(
          icon: _showSettings ? Icons.inbox_rounded : Icons.tune_rounded,
          tooltip: _showSettings ? 'Back to inbox' : 'Notification settings',
          onPressed: () => setState(() => _showSettings = !_showSettings),
        ),
      ],
      slivers: _showSettings
          ? _settingsSlivers()
          : _inboxSlivers(notifications, unread),
    );
  }

  List<Widget> _inboxSlivers(List<AppNotification> notifications, int unread) {
    return [
      if (unread > 0)
        SliverGutter(
          child: AvButton(
            label: 'Mark everything as read',
            variant: AvButtonVariant.outline,
            size: AvButtonSize.small,
            icon: Icons.done_all_rounded,
            expand: true,
            onPressed: () =>
                ref.read(notificationStoreProvider.notifier).markAllRead(),
          ),
        ),
      if (notifications.isEmpty)
        const SliverGutter(
          top: AvSpace.xl,
          child: AvEmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'Nothing here',
            message:
                'Reminders, coach assignments and analysis updates land '
                'in this inbox.',
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AvSpace.gutter,
            AvSpace.md,
            AvSpace.gutter,
            0,
          ),
          sliver: SliverList.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: AvSpace.xs),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(
                notification: notification,
                onTap: () {
                  ref
                      .read(notificationStoreProvider.notifier)
                      .markRead(notification.id);
                  final route = notification.actionRoute;
                  if (route != null) context.push(route);
                },
              );
            },
          ),
        ),
    ];
  }

  List<Widget> _settingsSlivers() {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);

    return [
      const SliverGutter(
        child: AvSectionHeader(
          title: 'What you hear about',
          padding: EdgeInsets.only(bottom: AvSpace.sm),
        ),
      ),
      SliverGutter(
        child: AvCard(
          child: Column(
            children: [
              for (final kind in NotificationKind.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      AvGlyph(
                        icon: kind.icon,
                        color: kind.color,
                        background: kind.color.withValues(alpha: 0.12),
                        size: 34,
                      ),
                      const SizedBox(width: AvSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kind.label, style: AvType.titleSmall.primary),
                            Text(_describe(kind), style: AvType.caption.faint),
                          ],
                        ),
                      ),
                      Switch(
                        value: settings.notificationOptIns[kind.name] ?? true,
                        onChanged: kind == NotificationKind.safety
                            ? null
                            : (value) => controller.setNotificationOptIn(
                                kind.name,
                                value,
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
          title: 'Quiet hours',
          accent: AvColors.insight,
          padding: EdgeInsets.only(bottom: AvSpace.sm),
        ),
      ),
      SliverGutter(
        child: AvCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hold non-urgent notifications',
                          style: AvType.titleSmall.primary,
                        ),
                        Text(
                          'Safety and guardian messages always come through.',
                          style: AvType.caption.faint,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: settings.quietHoursEnabled,
                    onChanged: (value) => controller.update(
                      (s) => s.copyWith(quietHoursEnabled: value),
                    ),
                  ),
                ],
              ),
              if (settings.quietHoursEnabled) ...[
                const SizedBox(height: AvSpace.sm),
                const AvSeparator(),
                const SizedBox(height: AvSpace.sm),
                _HourRow(
                  label: 'From',
                  hour: settings.quietHoursStartHour,
                  onChanged: (hour) => controller.update(
                    (s) => s.copyWith(quietHoursStartHour: hour),
                  ),
                ),
                _HourRow(
                  label: 'Until',
                  hour: settings.quietHoursEndHour,
                  onChanged: (hour) => controller.update(
                    (s) => s.copyWith(quietHoursEndHour: hour),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      SliverGutter(
        top: AvSpace.lg,
        child: AvTintCard(
          tint: AvColors.canvasSunken,
          child: Text(
            'This product does not send streak-pressure notifications or '
            'push more than three reminders a week. Training habits should '
            'come from the plan, not from the phone.',
            style: AvType.caption.muted,
          ),
        ),
      ),
    ];
  }

  String _describe(NotificationKind kind) => switch (kind) {
    NotificationKind.training => 'Scheduled sessions and plan reminders',
    NotificationKind.assignment => 'New work and feedback from a coach',
    NotificationKind.progress => 'Goals reached and records broken',
    NotificationKind.analysis => 'When a cloud analysis finishes',
    NotificationKind.account => 'Billing, plan and device changes',
    NotificationKind.safety =>
      'Guardian approvals and safety notices, always on',
  };
}

class _HourRow extends StatelessWidget {
  const _HourRow({
    required this.label,
    required this.hour,
    required this.onChanged,
  });

  final String label;
  final int hour;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 54, child: Text(label, style: AvType.caption.muted)),
        Expanded(
          child: Slider(
            value: hour.toDouble(),
            min: 0,
            max: 23,
            divisions: 23,
            onChanged: (value) => onChanged(value.round()),
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            '${hour.toString().padLeft(2, '0')}:00',
            textAlign: TextAlign.right,
            style: AvType.tabular(AvType.metricSmall).primary,
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AvCard(
      onTap: onTap,
      color: notification.read ? AvColors.surface : AvColors.flareTint,
      border: notification.read ? null : Border.all(color: AvColors.flareSoft),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvGlyph(
            icon: notification.kind.icon,
            color: notification.kind.color,
            background: notification.kind.color.withValues(alpha: 0.12),
            size: 38,
          ),
          const SizedBox(width: AvSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: AvType.titleSmall.primary,
                      ),
                    ),
                    if (!notification.read)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AvColors.flare,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(notification.body, style: AvType.bodySmall.muted),
                const SizedBox(height: AvSpace.xs),
                Wrap(
                  spacing: AvSpace.md,
                  runSpacing: AvSpace.xxs,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      Fmt.relative(notification.createdAt),
                      style: AvType.caption.faint,
                    ),
                    if (notification.actionLabel != null)
                      AvTextAction(
                        label: notification.actionLabel!,
                        icon: Icons.arrow_forward_rounded,
                        onPressed: onTap,
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
