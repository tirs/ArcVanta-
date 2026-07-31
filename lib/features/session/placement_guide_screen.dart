import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../data/models/confidence.dart';
import '../../data/models/drill.dart';
import '../../data/seed/drill_catalog.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import '../../state/capture_pipeline.dart';
import '../../state/live_session.dart';

/// Teaches the athlete where to put the phone before capture begins.
///
/// Placement is the largest single driver of measurement quality, so it is an
/// explicit step with a diagram rather than a line of help text.
class PlacementGuideScreen extends ConsumerStatefulWidget {
  const PlacementGuideScreen({super.key, required this.drillId});

  final String drillId;

  @override
  ConsumerState<PlacementGuideScreen> createState() =>
      _PlacementGuideScreenState();
}

class _PlacementGuideScreenState extends ConsumerState<PlacementGuideScreen> {
  late Drill _drill;
  late CameraAngle _angle;
  late bool _stabilised = ref.read(tripodDeclaredProvider);

  @override
  void initState() {
    super.initState();
    _drill = DrillCatalog.byId(widget.drillId);
    _angle = _drill.recommendedAngle;
  }

  void _continue() {
    ref.read(liveSessionProvider.notifier).configure(_drill, _angle);
    context.push(AppRoute.calibration(_drill.id, _angle));
  }

  @override
  Widget build(BuildContext context) {
    return AvScaffold(
      title: 'Place your camera',
      subtitle: 'Step 1 of 2 \u00B7 ${_drill.name}',
      leading: const AvBackButton(),
      bottomBar: AvBottomBar(
        children: [
          Expanded(
            child: AvButton(
              label: 'Continue to calibration',
              size: AvButtonSize.large,
              expand: true,
              onPressed: _continue,
            ),
          ),
        ],
      ),
      slivers: [
        SliverGutter(child: _PlacementDiagram(angle: _angle)),
        SliverGutter(
          top: AvSpace.lg,
          child: Text('Camera angle', style: AvType.headingSmall.primary),
        ),
        SliverGutter(
          top: AvSpace.sm,
          child: Column(
            children: [
              for (final angle in CameraAngle.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: AvSpace.sm),
                  child: _AngleOption(
                    angle: angle,
                    selected: _angle == angle,
                    recommended: angle == _drill.recommendedAngle,
                    onTap: () => setState(() => _angle = angle),
                  ),
                ),
            ],
          ),
        ),
        const SliverGutter(
          top: AvSpace.md,
          child: AvSectionHeader(
            title: 'Before you start',
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              children: const [
                _CheckRow(
                  icon: Icons.straighten_rounded,
                  title: 'Distance',
                  detail:
                      'Five to seven metres from the shooting spot so the '
                      'whole motion stays in frame.',
                ),
                AvSeparator(inset: 34),
                _CheckRow(
                  icon: Icons.height_rounded,
                  title: 'Height',
                  detail:
                      'Waist to chest height, about one metre, with the '
                      'lens level rather than tilted up.',
                ),
                AvSeparator(inset: 34),
                _CheckRow(
                  icon: Icons.crop_free_rounded,
                  title: 'Framing',
                  detail:
                      'Both feet and the full rim visible through the '
                      'jump, with headroom above the release.',
                ),
                AvSeparator(inset: 34),
                _CheckRow(
                  icon: Icons.wb_sunny_rounded,
                  title: 'Light',
                  detail:
                      'Keep bright windows behind the camera. Backlight '
                      'behind the shooter costs tracking confidence.',
                ),
              ],
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.sm,
          child: AvCard(
            padding: const EdgeInsets.all(AvSpace.md),
            child: Row(
              children: [
                const AvGlyph(
                  icon: Icons.camera_outdoor_rounded,
                  color: AvColors.court,
                ),
                const SizedBox(width: AvSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tripod or stable prop',
                        style: AvType.titleMedium.primary,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Handheld capture adds motion the solver cannot '
                        'separate from the shooter.',
                        style: AvType.caption.muted,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _stabilised,
                  onChanged: (value) {
                    setState(() => _stabilised = value);
                    ref.read(tripodDeclaredProvider.notifier).set(value);
                  },
                ),
              ],
            ),
          ),
        ),
        if (!_stabilised)
          const SliverGutter(
            top: AvSpace.sm,
            child: AvUnavailableNotice(
              metric: 'Release height, apex and entry angle',
              reason:
                  'Handheld capture cannot hold the court plane steady '
                  'enough to solve height. These metrics will be recorded at '
                  'low confidence and left out of your trends.',
            ),
          ),
      ],
    );
  }
}

class _PlacementDiagram extends StatelessWidget {
  const _PlacementDiagram({required this.angle});

  final CameraAngle angle;

  @override
  Widget build(BuildContext context) {
    return AvInkCard(
      padding: const EdgeInsets.all(AvSpace.md),
      showCourtLines: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AvSpace.sm,
            runSpacing: AvSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                'TOP-DOWN VIEW',
                style: AvType.overline.copyWith(color: AvColors.textOnInkMuted),
              ),
              AvPill(label: angle.label, color: AvColors.flare, filled: true),
            ],
          ),
          const SizedBox(height: AvSpace.md),
          AspectRatio(
            aspectRatio: 1.42,
            child: CustomPaint(painter: _PlacementPainter(angle: angle)),
          ),
          const SizedBox(height: AvSpace.md),
          Text(
            angle.description,
            style: AvType.bodySmall.copyWith(color: AvColors.textOnInkMuted),
          ),
        ],
      ),
    );
  }
}

class _PlacementPainter extends CustomPainter {
  const _PlacementPainter({required this.angle});

  final CameraAngle angle;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = AvColors.textOnInkMuted.withValues(alpha: 0.5);

    final court = Rect.fromLTWH(
      size.width * 0.06,
      size.height * 0.06,
      size.width * 0.88,
      size.height * 0.88,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(court, const Radius.circular(6)),
      line,
    );

    final hoop = Offset(court.center.dx, court.top + court.height * 0.07);
    canvas.drawLine(
      Offset(court.left, hoop.dy),
      Offset(court.right, hoop.dy),
      line,
    );
    canvas.drawCircle(
      hoop,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = AvColors.flare,
    );

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(court.center.dx, court.top + court.height * 0.30),
        width: court.width * 0.26,
        height: court.height * 0.46,
      ),
      line,
    );

    canvas.drawArc(
      Rect.fromCircle(center: hoop, radius: court.width * 0.34),
      0,
      math.pi,
      false,
      line,
    );

    final shooter = Offset(
      court.center.dx - court.width * 0.15,
      court.top + court.height * 0.58,
    );

    final camera = switch (angle) {
      CameraAngle.side => Offset(
        court.left + court.width * 0.07,
        shooter.dy - court.height * 0.02,
      ),
      CameraAngle.front => Offset(
        court.center.dx + court.width * 0.04,
        hoop.dy + court.height * 0.05,
      ),
      CameraAngle.rear => Offset(
        shooter.dx - court.width * 0.02,
        court.bottom - court.height * 0.08,
      ),
      CameraAngle.diagonal => Offset(
        court.left + court.width * 0.14,
        court.bottom - court.height * 0.12,
      ),
    };

    final direction = shooter - camera;
    final distance = direction.distance;
    final unit = direction / distance;
    final normal = Offset(-unit.dy, unit.dx);
    final reach = distance * 1.9;
    final spread = reach * 0.30;

    canvas.drawPath(
      Path()
        ..moveTo(camera.dx, camera.dy)
        ..lineTo(
          camera.dx + unit.dx * reach + normal.dx * spread,
          camera.dy + unit.dy * reach + normal.dy * spread,
        )
        ..lineTo(
          camera.dx + unit.dx * reach - normal.dx * spread,
          camera.dy + unit.dy * reach - normal.dy * spread,
        )
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AvColors.flare.withValues(alpha: 0.30),
            AvColors.flare.withValues(alpha: 0.02),
          ],
        ).createShader(court),
    );

    // Shooting line from athlete to rim.
    _dashed(
      canvas,
      shooter,
      hoop,
      AvColors.overlayTrace.withValues(alpha: 0.6),
    );

    canvas.drawCircle(shooter, 6.5, Paint()..color = AvColors.textOnInk);
    canvas.drawCircle(
      shooter,
      6.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AvColors.ink,
    );
    _label(canvas, shooter + const Offset(0, 12), 'SHOOTER');

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: camera, width: 20, height: 14),
        const Radius.circular(3),
      ),
      Paint()..color = AvColors.flare,
    );
    canvas.drawCircle(camera, 3.2, Paint()..color = AvColors.ink);
    _label(canvas, camera + const Offset(0, 14), 'CAMERA');
  }

  void _dashed(Canvas canvas, Offset from, Offset to, Color color) {
    final paint = Paint()
      ..strokeWidth = 1.2
      ..color = color;
    final delta = to - from;
    final length = delta.distance;
    final unit = delta / length;
    var travelled = 0.0;
    while (travelled < length) {
      final end = math.min(travelled + 5, length);
      canvas.drawLine(from + unit * travelled, from + unit * end, paint);
      travelled += 10;
    }
  }

  void _label(Canvas canvas, Offset centre, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: AvType.overline.copyWith(
          color: AvColors.textOnInkMuted,
          fontSize: 8,
          letterSpacing: 0.9,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, centre - Offset(painter.width / 2, 0));
  }

  @override
  bool shouldRepaint(_PlacementPainter oldDelegate) =>
      oldDelegate.angle != angle;
}

class _AngleOption extends StatelessWidget {
  const _AngleOption({
    required this.angle,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  final CameraAngle angle;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AvPressable(
      onTap: onTap,
      borderRadius: AvRadius.allMd,
      semanticLabel: '${angle.label} camera angle',
      child: AnimatedContainer(
        duration: AvMotion.fast,
        padding: const EdgeInsets.all(AvSpace.md),
        decoration: BoxDecoration(
          color: selected ? AvColors.flareTint : AvColors.surface,
          borderRadius: AvRadius.allMd,
          border: Border.all(
            color: selected ? AvColors.flare : AvColors.hairline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvGlyph(
              icon: angle.icon,
              color: selected ? AvColors.flare : AvColors.textMuted,
              background: selected ? AvColors.flareSoft : AvColors.canvasSunken,
              size: 38,
            ),
            const SizedBox(width: AvSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          angle.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AvType.titleMedium.primary,
                        ),
                      ),
                      if (recommended) ...[
                        const SizedBox(width: AvSpace.xs),
                        const AvPill(
                          label: 'Recommended',
                          color: AvColors.court,
                          dense: true,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(angle.description, style: AvType.caption.muted),
                ],
              ),
            ),
            const SizedBox(width: AvSpace.sm),
            AnimatedContainer(
              duration: AvMotion.fast,
              margin: const EdgeInsets.only(top: 2),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AvColors.flare : Colors.transparent,
                border: Border.all(
                  color: selected ? AvColors.flare : AvColors.hairlineStrong,
                  width: 1.6,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AvSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AvColors.flare),
          const SizedBox(width: AvSpace.md),
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
        ],
      ),
    );
  }
}
