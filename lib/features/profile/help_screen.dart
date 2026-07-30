import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../data/models/confidence.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';

class _Article {
  const _Article({
    required this.title,
    required this.body,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color accent;
}

/// Support content, written to answer the questions people actually ask about
/// a measurement product: why a number moved, why one is missing, and what the
/// system can and cannot see.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  String _query = '';

  static const _articles = <_Article>[
    _Article(
      title: 'Getting an accurate setup',
      icon: Icons.videocam_rounded,
      accent: AvColors.court,
      body:
          'Put the phone on a tripod or a stable prop at waist to chest '
          'height, five to seven metres from the shooting spot, with the lens '
          'level rather than tilted. Both feet and the whole rim must stay in '
          'frame through the jump. Keep bright windows behind the camera. '
          'Handheld capture is supported but release height, apex and entry '
          'angle drop to low confidence because the court plane moves.',
    ),
    _Article(
      title: 'Why a measurement says "not available"',
      icon: Icons.visibility_off_rounded,
      accent: AvColors.unavailable,
      body:
          'Every metric depends on camera placement. A side view cannot see '
          'left and right error; a front view cannot separate arc height from '
          'distance; a rear view cannot see the lower body through the load. '
          'Rather than estimate a number it cannot support, the app marks the '
          'metric unavailable and tells you which placement would measure it.',
    ),
    _Article(
      title: 'What the confidence levels mean',
      icon: Icons.verified_rounded,
      accent: AvColors.made,
      body:
          'High means detection, tracking and calibration all met their '
          'thresholds. Medium means the value is usable but one input was '
          'weaker than target, so small changes should be treated with care. '
          'Low means the measurement is shown for reference only: it never '
          'drives a coaching cue and never enters a trend line.',
    ),
    _Article(
      title: 'Why my percentage moved without me changing anything',
      icon: Icons.query_stats_rounded,
      accent: AvColors.insight,
      body:
          'Small samples move a lot. Twenty attempts is enough to notice a '
          'pattern and not enough to prove one. The progress screen states how '
          'much of any movement is explained by camera setup rather than '
          'performance, and how many attempts the number is based on.',
    ),
    _Article(
      title: 'Correcting a result the system got wrong',
      icon: Icons.edit_note_rounded,
      accent: AvColors.flare,
      body:
          'Open the shot from the timeline and choose the correct outcome, '
          'or fix the last attempt from the live controls without stopping. '
          'Corrections update your totals immediately and are stored as '
          'corrections, separate from the model output, so the record of what '
          'the system saw stays intact.',
    ),
    _Article(
      title: 'What the app cannot measure',
      icon: Icons.help_outline_rounded,
      accent: AvColors.caution,
      body:
          'It measures shooting from video. It does not measure force, '
          'fatigue, injury risk or anything inside the body, and it is not a '
          'medical device. Defensive pressure, game context and decision '
          'making are outside what a fixed camera can see.',
    ),
    _Article(
      title: 'Battery, heat and long sessions',
      icon: Icons.local_fire_department_rounded,
      accent: AvColors.miss,
      body:
          'Continuous vision processing is demanding. With the thermal guard '
          'on, the app simplifies the overlay before it lowers measurement '
          'quality. Expect roughly ninety minutes of continuous capture on a '
          'full charge at 60 fps, longer at 30.',
    ),
    _Article(
      title: 'Sharing with a coach or guardian',
      icon: Icons.shield_rounded,
      accent: AvColors.court,
      body:
          'Nothing is shared until you send it. Coaches see summaries and '
          'the clips you send them. On accounts under sixteen, a guardian '
          'approves coach access before any shot-level data or video is '
          'visible, and public sharing is never available.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final articles = _articles
        .where(
          (a) =>
              _query.isEmpty ||
              a.title.toLowerCase().contains(_query.toLowerCase()) ||
              a.body.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList(growable: false);

    return AvScaffold(
      title: 'Help',
      subtitle: 'Setup, accuracy and what the system can see',
      leading: const AvBackButton(),
      slivers: [
        SliverGutter(
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Search help',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.md,
          child: AvCard(
            onTap: () => context.push(AppRoute.onboarding),
            child: Row(
              children: [
                const AvGlyph(
                  icon: Icons.play_circle_outline_rounded,
                  color: AvColors.flare,
                  background: AvColors.flareSoft,
                  size: 42,
                ),
                const SizedBox(width: AvSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Replay the introduction',
                        style: AvType.titleMedium.primary,
                      ),
                      Text(
                        'Four screens on how measurement and confidence work',
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
            title: 'Camera placement reference',
            accent: AvColors.court,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              children: [
                for (final angle in CameraAngle.values) ...[
                  if (angle != CameraAngle.values.first)
                    const AvSeparator(inset: 34),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AvSpace.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(angle.icon, size: 18, color: AvColors.court),
                        const SizedBox(width: AvSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                angle.label,
                                style: AvType.titleSmall.primary,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                angle.description,
                                style: AvType.caption.muted,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Confidence at a glance',
            accent: AvColors.made,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              children: [
                for (final level in ConfidenceLevel.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AvConfidenceBadge(level: level, compact: true),
                        const SizedBox(width: AvSpace.sm),
                        Expanded(
                          child: Text(
                            level.explanation,
                            style: AvType.caption.muted,
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
            title: 'Common questions',
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        if (articles.isEmpty)
          const SliverGutter(
            top: AvSpace.md,
            child: AvEmptyState(
              icon: Icons.search_off_rounded,
              title: 'Nothing matches',
              message: 'Try a different word, or contact support below.',
            ),
          )
        else
          for (final article in articles)
            SliverGutter(
              top: AvSpace.xs,
              child: _ArticleTile(article: article),
            ),
        SliverGutter(
          top: AvSpace.lg,
          child: AvTintCard(
            tint: AvColors.insightTint,
            borderColor: AvColors.insightSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AvGlyph(
                      icon: Icons.support_agent_rounded,
                      color: AvColors.insightDeep,
                      background: AvColors.insightSoft,
                      size: 36,
                    ),
                    const SizedBox(width: AvSpace.sm),
                    Expanded(
                      child: Text(
                        'Still stuck?',
                        style: AvType.titleMedium.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AvSpace.xs),
                Text(
                  'Send a diagnostic report with your last session. It '
                  'includes calibration scores and model versions, and never '
                  'includes video unless you attach it.',
                  style: AvType.caption.muted,
                ),
                const SizedBox(height: AvSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: AvButton(
                        label: 'Contact support',
                        variant: AvButtonVariant.insight,
                        size: AvButtonSize.small,
                        expand: true,
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Opening a support conversation'),
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(width: AvSpace.xs),
                    Expanded(
                      child: AvButton(
                        label: 'Send diagnostics',
                        variant: AvButtonVariant.outline,
                        size: AvButtonSize.small,
                        expand: true,
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Diagnostic report prepared'),
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
        SliverGutter(
          top: AvSpace.md,
          child: Center(
            child: Text(
              'Terms of service \u00B7 Privacy policy \u00B7 Licences',
              style: AvType.caption.faint,
            ),
          ),
        ),
      ],
    );
  }
}

class _ArticleTile extends StatefulWidget {
  const _ArticleTile({required this.article});

  final _Article article;

  @override
  State<_ArticleTile> createState() => _ArticleTileState();
}

class _ArticleTileState extends State<_ArticleTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    return AvCard(
      onTap: () => setState(() => _open = !_open),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvGlyph(
                icon: article.icon,
                color: article.accent,
                background: article.accent.withValues(alpha: 0.12),
                size: 36,
              ),
              const SizedBox(width: AvSpace.sm),
              Expanded(
                child: Text(article.title, style: AvType.titleSmall.primary),
              ),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: AvMotion.fast,
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AvColors.textFaint,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: AvMotion.normal,
            curve: AvMotion.emphasized,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.only(top: AvSpace.sm),
                    child: Text(article.body, style: AvType.bodySmall.muted),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
