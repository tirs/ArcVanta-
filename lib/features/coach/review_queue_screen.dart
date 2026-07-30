import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/profile.dart';
import '../../data/models/program.dart';
import '../../data/models/session.dart';
import '../../design/charts/av_shot_graphics.dart';
import '../../design/components/av_brand.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_stats.dart';
import '../../design/components/av_surface.dart';
import '../../state/stores.dart';
import 'athlete_detail_screen.dart';

/// Work queue for a coach: submitted assignments and the clips athletes flagged
/// for feedback, with a comment box that writes back to the session record.
class ReviewQueueScreen extends ConsumerStatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  ConsumerState<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends ConsumerState<ReviewQueueScreen> {
  @override
  Widget build(BuildContext context) {
    final assignments = ref
        .watch(assignmentStoreProvider)
        .where((a) => a.status == AssignmentStatus.submitted)
        .toList(growable: false);
    final sessions = ref.watch(sessionStoreProvider).take(3).toList();
    final roster = ref.watch(rosterProvider);

    return AvScaffold(
      title: 'Review queue',
      subtitle: '${assignments.length} submissions \u00B7 '
          '${sessions.length} sessions to comment on',
      leading: const AvBackButton(),
      slivers: [
        if (assignments.isEmpty && sessions.isEmpty)
          const SliverGutter(
            top: AvSpace.xl,
            child: AvEmptyState(
              icon: Icons.done_all_rounded,
              title: 'Queue is clear',
              message: 'New submissions land here as athletes finish their '
                  'assigned work.',
            ),
          ),
        if (assignments.isNotEmpty) ...[
          const SliverGutter(
            child: AvSectionHeader(
              title: 'Submitted assignments',
              accent: AvColors.caution,
              padding: EdgeInsets.only(bottom: AvSpace.sm),
            ),
          ),
          for (final assignment in assignments)
            SliverGutter(
              top: AvSpace.xs,
              child: AssignmentCard(
                assignment: assignment,
                showAthlete: true,
                onStatusChange: (status) => ref
                    .read(assignmentStoreProvider.notifier)
                    .setStatus(assignment.id, status),
              ),
            ),
        ],
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Sessions awaiting comment',
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        for (var i = 0; i < sessions.length; i++)
          SliverGutter(
            top: AvSpace.sm,
            child: _ReviewCard(
              session: sessions[i],
              athlete: roster[i % roster.length],
              onOpen: () => context.push(AppRoute.session(sessions[i].id)),
              onComment: (comment) => ref
                  .read(sessionStoreProvider.notifier)
                  .setCoachComment(sessions[i].id, comment),
            ),
          ),
      ],
    );
  }
}

class _ReviewCard extends StatefulWidget {
  const _ReviewCard({
    required this.session,
    required this.athlete,
    required this.onOpen,
    required this.onComment,
  });

  final TrainingSession session;
  final AthleteSummary athlete;
  final VoidCallback onOpen;
  final ValueChanged<String> onComment;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.session.coachComment ?? '');
  bool _composing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final athlete = widget.athlete;
    final shot = session.representativeMiss ?? session.bestMechanicsShot;

    return AvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvAvatar(
                initials: athlete.initials,
                color: athlete.accentColor,
                size: 40,
              ),
              const SizedBox(width: AvSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(athlete.name, style: AvType.titleMedium.primary),
                    Text(
                      '${session.drillName} \u00B7 '
                      '${Fmt.relative(session.startedAt)}',
                      style: AvType.caption.faint,
                    ),
                  ],
                ),
              ),
              AvIconButton(
                icon: Icons.open_in_new_rounded,
                tooltip: 'Open session',
                size: 34,
                onPressed: widget.onOpen,
              ),
            ],
          ),
          const SizedBox(height: AvSpace.sm),
          Row(
            children: [
              Expanded(
                child: AvStatTile(
                  label: 'Result',
                  value: '${session.makeCount}/${session.attemptCount}',
                  caption: '${session.percentage.toStringAsFixed(0)} per cent',
                  accent: AvColors.flare,
                ),
              ),
              const SizedBox(width: AvSpace.xs),
              Expanded(
                child: AvStatTile(
                  label: 'Mechanics',
                  value: session.averageMechanics.toStringAsFixed(0),
                  unit: '/100',
                  caption: 'session average',
                  accent: AvColors.insight,
                ),
              ),
            ],
          ),
          if (shot != null) ...[
            const SizedBox(height: AvSpace.sm),
            Row(
              children: [
                AvResultChip(result: shot.result, detail: shot.outcomeDetail),
                const SizedBox(width: AvSpace.xs),
                Expanded(
                  child: Text(
                    'Representative rep \u00B7 shot ${shot.index}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AvType.caption.faint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AvSpace.xs),
            AvArcDiagram(shot: shot, height: 130, showAnnotations: false),
          ],
          const SizedBox(height: AvSpace.sm),
          if (!_composing && (session.coachComment ?? '').isEmpty)
            AvButton(
              label: 'Write feedback',
              variant: AvButtonVariant.outline,
              size: AvButtonSize.small,
              icon: Icons.edit_rounded,
              expand: true,
              onPressed: () => setState(() => _composing = true),
            )
          else if (!_composing)
            AvTintCard(
              tint: AvColors.madeSoft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.record_voice_over_rounded,
                    size: 16,
                    color: AvColors.madeDeep,
                  ),
                  const SizedBox(width: AvSpace.sm),
                  Expanded(
                    child: Text(
                      session.coachComment!,
                      style: AvType.bodySmall.muted,
                    ),
                  ),
                  AvTextAction(
                    label: 'Edit',
                    onPressed: () => setState(() => _composing = true),
                  ),
                ],
              ),
            )
          else ...[
            TextField(
              controller: _controller,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'One thing to fix, one thing that worked',
              ),
            ),
            const SizedBox(height: AvSpace.sm),
            Row(
              children: [
                Expanded(
                  child: AvButton(
                    label: 'Cancel',
                    variant: AvButtonVariant.ghost,
                    size: AvButtonSize.small,
                    expand: true,
                    onPressed: () => setState(() => _composing = false),
                  ),
                ),
                const SizedBox(width: AvSpace.xs),
                Expanded(
                  child: AvButton(
                    label: 'Send feedback',
                    size: AvButtonSize.small,
                    expand: true,
                    onPressed: _controller.text.trim().isEmpty
                        ? null
                        : () {
                            widget.onComment(_controller.text.trim());
                            setState(() => _composing = false);
                          },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}