import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import 'av_surface.dart';

/// Explains a feature this build cannot deliver, and why.
///
/// The alternative — showing the screen populated with invented athletes and
/// assignments — makes the app impossible to evaluate: nothing on screen tells
/// you which parts are real. A feature that says plainly what it needs is more
/// trustworthy than one that fakes working.
class AvUnavailableFeature extends StatelessWidget {
  const AvUnavailableFeature({
    super.key,
    required this.icon,
    required this.headline,
    required this.body,
    this.footnote,
  });

  final IconData icon;
  final String headline;
  final String body;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return AvCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AvSpace.lg,
        vertical: AvSpace.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvGlyph(icon: icon, color: AvColors.insight, size: 44),
              const SizedBox(width: AvSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: AvType.headingSmall.primary,
                    ),
                    const SizedBox(height: AvSpace.xs),
                    Text(body, style: AvType.bodySmall.muted),
                  ],
                ),
              ),
            ],
          ),
          if (footnote != null) ...[
            const SizedBox(height: AvSpace.md),
            AvRule(),
            const SizedBox(height: AvSpace.md),
            Text(footnote!, style: AvType.caption.muted),
          ],
        ],
      ),
    );
  }
}

/// Marks a screen whose numbers include the sample history.
///
/// Deliberately not dismissible. The whole reason the sample data is allowed
/// to exist is that it can never be mistaken for a record of real shooting,
/// and a banner the user can swipe away would not carry that guarantee.
class AvSampleDataBanner extends StatelessWidget {
  const AvSampleDataBanner({super.key, this.onTurnOff});

  final VoidCallback? onTurnOff;

  @override
  Widget build(BuildContext context) {
    return AvCautionBanner(
      title: 'Sample data is on',
      body: onTurnOff == null
          ? 'These numbers are examples, not your shooting.'
          : 'These numbers are examples, not your shooting. Tap to turn it '
                'off.',
      onTap: onTurnOff,
    );
  }
}

/// Marks a session that ran with no analysis models loaded.
///
/// Separate from [AvSampleDataBanner] because the remedy is different: sample
/// data is a switch the athlete can flick, whereas this resolves itself only
/// when the models are installed, so there is nothing to tap.
class AvRehearsalBanner extends StatelessWidget {
  const AvRehearsalBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const AvCautionBanner(
      title: 'Nothing was measured',
      body:
          'This session ran without the analysis models, so every number on '
          'this screen is a placeholder. It is kept in your history for the '
          'record, and left out of your totals, trends and personal bests.',
    );
  }
}

/// A non-dismissible strip that qualifies the numbers under it.
///
/// Deliberately not dismissible. The reason these numbers are allowed on
/// screen at all is that they can never be mistaken for real shooting, and a
/// banner the user can swipe away would not carry that guarantee.
class AvCautionBanner extends StatelessWidget {
  const AvCautionBanner({
    super.key,
    required this.title,
    required this.body,
    this.onTap,
  });

  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AvCard(
      color: AvColors.cautionSoft,
      shadows: const [],
      border: Border.all(color: AvColors.caution.withValues(alpha: 0.35)),
      padding: const EdgeInsets.symmetric(
        horizontal: AvSpace.md,
        vertical: AvSpace.sm,
      ),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.science_outlined,
            size: 18,
            color: AvColors.caution,
          ),
          const SizedBox(width: AvSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AvType.label.copyWith(color: AvColors.caution),
                ),
                const SizedBox(height: 2),
                Text(body, style: AvType.caption.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
