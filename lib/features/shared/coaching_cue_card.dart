import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../data/models/session.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_surface.dart';

/// Presents one coaching statement together with the evidence behind it.
///
/// Human coach feedback and automated feedback use different colours, glyphs
/// and source labels so the athlete always knows who is speaking.
class CoachingCueCard extends StatefulWidget {
  const CoachingCueCard({
    super.key,
    required this.cue,
    this.onDrillTap,
    this.compact = false,
  });

  final CoachingCue cue;
  final ValueChanged<String>? onDrillTap;
  final bool compact;

  @override
  State<CoachingCueCard> createState() => _CoachingCueCardState();
}

class _CoachingCueCardState extends State<CoachingCueCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cue = widget.cue;
    final accent = cue.source.color;
    final hasEvidence = cue.evidence.isNotEmpty;

    return AvCard(
      padding: const EdgeInsets.all(AvSpace.md),
      color: accent.withValues(alpha: 0.05),
      border: Border.all(color: accent.withValues(alpha: 0.24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvGlyph(icon: cue.source.icon, color: accent, size: 32),
              const SizedBox(width: AvSpace.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cue.authorName ?? cue.source.label,
                      style: AvType.label.copyWith(color: accent),
                    ),
                    if (cue.authorName != null)
                      Text(cue.source.label, style: AvType.overline.faint),
                  ],
                ),
              ),
              AvConfidenceBadge(level: cue.confidence, compact: true),
            ],
          ),
          const SizedBox(height: AvSpace.sm),
          Text(cue.headline, style: AvType.headingSmall.primary),
          const SizedBox(height: 6),
          Text(
            cue.detail,
            style: AvType.bodySmall.secondary,
            maxLines: _expanded || widget.compact ? null : 3,
            overflow: _expanded || widget.compact
                ? TextOverflow.clip
                : TextOverflow.ellipsis,
          ),
          if (hasEvidence && _expanded) ...[
            const SizedBox(height: AvSpace.sm),
            Container(
              padding: const EdgeInsets.all(AvSpace.sm),
              decoration: BoxDecoration(
                color: AvColors.surface,
                borderRadius: AvRadius.allSm,
                border: Border.all(color: AvColors.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BASED ON', style: AvType.overline.faint),
                  const SizedBox(height: 6),
                  for (final item in cue.evidence)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(top: 6, right: 8),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: AvRadius.pill,
                            ),
                          ),
                          Expanded(
                            child: Text(item, style: AvType.caption.secondary),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AvSpace.sm),
          Wrap(
            spacing: AvSpace.md,
            runSpacing: AvSpace.xs,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (hasEvidence)
                AvTextAction(
                  label: _expanded ? 'Hide evidence' : 'Show evidence',
                  icon: _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: accent,
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              if (cue.suggestedDrillId != null && widget.onDrillTap != null)
                AvButton(
                  label: 'Open drill',
                  size: AvButtonSize.small,
                  variant: AvButtonVariant.outline,
                  trailingIcon: Icons.arrow_forward_rounded,
                  onPressed: () => widget.onDrillTap!(cue.suggestedDrillId!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
