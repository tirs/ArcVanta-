import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../design/charts/av_court_map.dart';
import '../../design/components/av_brand.dart';
import '../../design/components/av_brand_scaffold.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_surface.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _Page(
      eyebrow: 'One phone, one tripod',
      title: 'Every attempt counted\nwithout touching the screen',
      body:
          'Place the phone, start the drill and shoot. The camera finds you, '
          'the ball and the rim, then records makes, attempts, streaks and '
          'shot locations while you keep working.',
      accent: AvColors.flare,
      art: _ArtKind.counting,
    ),
    _Page(
      eyebrow: 'Measured, not guessed',
      title: 'Mechanics you can act on\nthe same session',
      body:
          'Release angle, entry angle, elbow line, knee flexion, guide-hand '
          'separation, landing balance and timing, each with the camera '
          'placement it needs and the confidence it earned.',
      accent: AvColors.insight,
      art: _ArtKind.mechanics,
    ),
    _Page(
      eyebrow: 'Honest by design',
      title: 'Nothing is claimed\nwithout evidence',
      body:
          'Shot counts and angles come from the vision pipeline, never from a '
          'language model. When calibration is weak the value is hidden or '
          'shown as a range instead of a false decimal.',
      accent: AvColors.court,
      art: _ArtKind.confidence,
    ),
    _Page(
      eyebrow: 'Private by default',
      title: 'Video stays on the phone,\nfull stop',
      body:
          'Detection, pose and every measured angle are computed here and '
          'work with no connection at all. Nothing is uploaded, because this '
          'build has nowhere to upload it to.',
      accent: AvColors.made,
      art: _ArtKind.privacy,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      context.go(AppRoute.auth);
    } else {
      _controller.nextPage(duration: AvMotion.slow, curve: AvMotion.emphasized);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];

    return AvBrandScaffold(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AvSpace.gutter,
              AvSpace.md,
              AvSpace.gutter,
              0,
            ),
            child: Row(
              children: [
                const Flexible(
                  child: AvBrandLockup(
                    markSize: 34,
                    fontSize: 17,
                    onInk: true,
                  ),
                ),
                const SizedBox(width: AvSpace.sm),
                const Spacer(),
                AvTextAction(
                  label: 'Skip',
                  icon: null,
                  color: AvColors.textOnInkMuted,
                  onPressed: () => context.go(AppRoute.auth),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (index) => setState(() => _page = index),
              itemBuilder: (context, index) => _PageView(page: _pages[index]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AvSpace.gutter,
              AvSpace.md,
              AvSpace.gutter,
              AvSpace.lg,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _pages.length; i++)
                      AnimatedContainer(
                        duration: AvMotion.normal,
                        curve: AvMotion.emphasized,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 6,
                        width: i == _page ? 26 : 6,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? page.accent
                              : Colors.white.withValues(alpha: 0.24),
                          borderRadius: AvRadius.pill,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AvSpace.lg),
                AvButton(
                  label: _page == _pages.length - 1
                      ? 'Set up your profile'
                      : 'Continue',
                  onPressed: _next,
                  size: AvButtonSize.large,
                  expand: true,
                  trailingIcon: Icons.arrow_forward_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _ArtKind { counting, mechanics, confidence, privacy }

class _Page {
  const _Page({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.accent,
    required this.art,
  });

  final String eyebrow;
  final String title;
  final String body;
  final Color accent;
  final _ArtKind art;
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AvSpace.gutter,
        AvSpace.lg,
        AvSpace.gutter,
        AvSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OnboardingArt(kind: page.art, accent: page.accent),
          const SizedBox(height: AvSpace.xl),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: page.accent.withValues(alpha: 0.12),
              borderRadius: AvRadius.pill,
            ),
            child: Text(
              page.eyebrow.toUpperCase(),
              style: AvType.overline.copyWith(color: page.accent),
            ),
          ),
          const SizedBox(height: AvSpace.md),
          Text(page.title, style: AvType.displayMedium.onInk),
          const SizedBox(height: AvSpace.sm),
          Text(page.body, style: AvType.body.onInkMuted),
        ],
      ),
    );
  }
}

class _OnboardingArt extends StatelessWidget {
  const _OnboardingArt({required this.kind, required this.accent});

  final _ArtKind kind;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AvInkCard(
      accent: accent,
      raised: true,
      padding: const EdgeInsets.all(AvSpace.lg),
      child: SizedBox(
        height: 232,
        child: switch (kind) {
          _ArtKind.counting => const _CountingArt(),
          _ArtKind.mechanics => const _MechanicsArt(),
          _ArtKind.confidence => const _ConfidenceArt(),
          _ArtKind.privacy => const _PrivacyArt(),
        },
      ),
    );
  }
}

class _CountingArt extends StatelessWidget {
  const _CountingArt();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('EXAMPLE COUNT', style: AvType.overline.onInkMuted),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('23', style: AvType.heroMetric.onInk),
                    Text(' / 48', style: AvType.headingMedium.onInkMuted),
                  ],
                ),
              ),
              Text(
                'MAKES / ATTEMPTS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AvType.overline.onInkMuted,
              ),
              // The gap gives way first when the reader's text is large, so the
              // figures keep their room instead of the card clipping.
              const Flexible(child: SizedBox(height: AvSpace.md)),
              Wrap(
                spacing: AvSpace.lg,
                runSpacing: AvSpace.sm,
                children: const [
                  _MiniStat(label: 'Streak', value: '6'),
                  _MiniStat(label: 'Swish', value: '41%'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AvSpace.md),
        Expanded(
          child: AspectRatio(
            aspectRatio: CourtGeometry.aspect,
            child: CustomPaint(
              painter: CourtPainter(
                lineColor: Colors.white.withValues(alpha: 0.36),
                keyColor: AvColors.flare.withValues(alpha: 0.14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AvType.overline.onInkMuted),
        const SizedBox(height: 3),
        Text(value, style: AvType.metricMedium.onInk),
      ],
    );
  }
}

class _MechanicsArt extends StatelessWidget {
  const _MechanicsArt();

  static const _rows = [
    ('Release angle', '51.4\u00B0', 0.78, AvColors.insight),
    ('Entry angle', '44.3\u00B0', 0.86, AvColors.court),
    ('Elbow line', '87\u00B0', 0.64, AvColors.flare),
    ('Knee flexion', '126\u00B0', 0.71, AvColors.made),
    ('Follow-through', '690 ms', 0.92, AvColors.caution),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('EXAMPLE MEASUREMENTS', style: AvType.overline.onInkMuted),
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 108,
                  child: Text(row.$1, style: AvType.caption.onInkMuted),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: AvRadius.pill,
                    child: LinearProgressIndicator(
                      value: row.$3,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.10),
                      valueColor: AlwaysStoppedAnimation(row.$4),
                    ),
                  ),
                ),
                const SizedBox(width: AvSpace.xs),
                SizedBox(
                  width: 58,
                  child: Text(
                    row.$2,
                    textAlign: TextAlign.right,
                    style: AvType.tabular(AvType.titleSmall).onInk,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ConfidenceArt extends StatelessWidget {
  const _ConfidenceArt();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ConfidenceRow(
          icon: Icons.verified_rounded,
          color: AvColors.made,
          title: 'High \u00B7 Release angle 51.4\u00B0',
          detail: 'Side placement, court plane locked, ball tracked 100%.',
        ),
        _ConfidenceRow(
          icon: Icons.change_history_rounded,
          color: AvColors.caution,
          title: 'Medium \u00B7 Jump height 61 \u00B14 cm',
          detail: 'Shown as a range because rim pixels were limited.',
        ),
        _ConfidenceRow(
          icon: Icons.remove_circle_outline_rounded,
          color: AvColors.unavailable,
          title: 'Unavailable \u00B7 Left-right deviation',
          detail: 'Side placement cannot measure it. Use front or rear.',
        ),
      ],
    );
  }
}

class _ConfidenceRow extends StatelessWidget {
  const _ConfidenceRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: AvRadius.allXs,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: AvSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AvType.titleSmall.onInk),
              const SizedBox(height: 2),
              Text(detail, style: AvType.caption.onInkMuted),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivacyArt extends StatelessWidget {
  const _PrivacyArt();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _PrivacyRow(
          label: 'Live analysis on this device',
          value: 'Always',
          on: true,
        ),
        _PrivacyRow(label: 'Backup off the device', value: 'None', on: false),
        _PrivacyRow(
          label: 'Share clips with your coach',
          value: 'Not built',
          on: false,
        ),
        _PrivacyRow(
          label: 'Contribute video to model training',
          value: 'Never',
          on: false,
        ),
        const SizedBox(height: 2),
        Text(
          'Guardian approval is required before a minor account can share '
          'anything outside the device.',
          style: AvType.caption.onInkMuted,
        ),
      ],
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({
    required this.label,
    required this.value,
    required this.on,
  });

  final String label;
  final String value;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          on ? Icons.lock_rounded : Icons.lock_open_rounded,
          size: 15,
          color: on ? AvColors.made : AvColors.textOnInkMuted,
        ),
        const SizedBox(width: AvSpace.xs),
        Expanded(child: Text(label, style: AvType.bodySmall.onInk)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: on
                ? AvColors.made.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: AvRadius.pill,
          ),
          child: Text(
            value,
            style: AvType.overline.copyWith(
              color: on ? AvColors.made : AvColors.textOnInkMuted,
            ),
          ),
        ),
      ],
    );
  }
}
