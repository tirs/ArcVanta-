import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../models/confidence.dart';
import '../models/shot.dart';

/// Builds coherent shot records from a deterministic seed.
///
/// The generator exists so the interface is always exercised with data that
/// behaves like real capture output: mechanics correlate with results, misses
/// cluster around a dominant error, confidence degrades with occlusion, and a
/// small share of attempts stay uncertain rather than being forced into a
/// class. Replacing this with the on-device pipeline output requires no change
/// above the repository layer.
class ShotFactory {
  ShotFactory({
    required this.seed,
    required this.baseAccuracy,
    required this.mechanicsCentre,
    required this.lateralBias,
    required this.releaseAngleCentre,
  }) : _random = math.Random(seed);

  final int seed;

  /// Expected make rate before zone and fatigue adjustments, 0 to 1.
  final double baseAccuracy;
  final double mechanicsCentre;

  /// Systematic left/right error in centimetres. Negative is left.
  final double lateralBias;
  final double releaseAngleCentre;

  final math.Random _random;

  double _gauss(double mean, double deviation) {
    final u1 = 1 - _random.nextDouble();
    final u2 = _random.nextDouble();
    final z = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
    return mean + z * deviation;
  }

  List<Shot> build({
    required String sessionId,
    required List<CourtZone> zones,
    required ShotType type,
    required int count,
    required double calibrationQuality,
    Duration interval = const Duration(seconds: 17),
  }) {
    final shots = <Shot>[];
    var elapsed = const Duration(seconds: 9);

    for (var i = 0; i < count; i++) {
      final zone = zones[i % zones.length];
      final fatigue = i / math.max(count - 1, 1);

      final zoneModifier = switch (zone) {
        CourtZone.freeThrow => 0.16,
        CourtZone.paint || CourtZone.restrictedArea => 0.22,
        CourtZone.leftElbow || CourtZone.rightElbow => 0.04,
        CourtZone.leftBaselineMid || CourtZone.rightBaselineMid => -0.01,
        CourtZone.topKey3 => -0.06,
        CourtZone.leftWing3 || CourtZone.rightWing3 => -0.08,
        CourtZone.leftCorner3 || CourtZone.rightCorner3 => -0.04,
      };

      final makeChance =
          (baseAccuracy + zoneModifier - fatigue * 0.07).clamp(0.05, 0.95);
      final roll = _random.nextDouble();

      final mechanics = _gauss(
        mechanicsCentre - fatigue * 3.4 + (roll < makeChance ? 2.8 : -3.1),
        4.1,
      ).clamp(38, 99).toDouble();

      // Occlusion and blur occasionally reduce evidence quality.
      final evidence = (calibrationQuality -
              _random.nextDouble() * 0.22 -
              (zone.isThree ? 0.05 : 0.0))
          .clamp(0.0, 1.0);
      var confidence = ConfidenceLevel.fromScore(evidence);

      ShotResult result;
      ShotOutcomeDetail detail;

      if (evidence < 0.58 && _random.nextDouble() < 0.42) {
        result = ShotResult.uncertain;
        detail = ShotOutcomeDetail.undetermined;
        confidence = ConfidenceLevel.low;
      } else if (roll < makeChance) {
        result = ShotResult.made;
        final swish = _random.nextDouble() < 0.46 && mechanics > 78;
        detail = swish
            ? ShotOutcomeDetail.swish
            : (_random.nextDouble() < 0.72
                ? ShotOutcomeDetail.rimMake
                : ShotOutcomeDetail.backboardMake);
      } else {
        result = ShotResult.missed;
        detail = _missDetail(mechanics);
      }

      final lateral = _gauss(lateralBias, 6.2) +
          (result == ShotResult.missed ? _gauss(0, 4.4) : 0);
      final depth = _gauss(result == ShotResult.made ? 1.4 : -3.6, 5.8);
      final releaseAngle =
          _gauss(releaseAngleCentre - fatigue * 1.1, 2.6).clamp(38, 62);
      final entryAngle = (releaseAngle * 0.86 + 8.4 + _gauss(0, 1.6))
          .clamp(31, 56)
          .toDouble();
      final apex = _gauss(3.25 + (releaseAngle - 50) * 0.03, 0.16);
      final flight = (780 + (apex - 3.2) * 210 + _gauss(0, 44)).round();

      shots.add(
        Shot(
          id: '$sessionId-s${i + 1}',
          index: i + 1,
          offsetFromStart: elapsed,
          result: result,
          outcomeDetail: detail,
          zone: zone,
          type: type,
          confidence: confidence,
          releaseAngle: releaseAngle.toDouble(),
          entryAngle: entryAngle,
          apexHeightM: apex,
          releaseHeightM: _gauss(2.34, 0.04),
          ballSpeedMs: _gauss(7.1, 0.28),
          flightTimeMs: flight,
          lateralDeviationCm: lateral,
          depthCm: depth,
          elbowAngle: _gauss(87.5 + (mechanics - 80) * 0.22, 3.1),
          kneeFlexion: _gauss(126 - fatigue * 4.5, 4.8),
          guideHandSeparationCm: _gauss(4.2 + (85 - mechanics) * 0.06, 1.1),
          releaseTimeMs: (_gauss(612 + fatigue * 26, 38)).round(),
          followThroughMs: (_gauss(mechanics > 82 ? 690 : 540, 82)).round(),
          landingDriftCm: _gauss(mechanics > 82 ? 3.1 : 8.6, 3.4).abs(),
          balanceScore: _gauss(mechanics - 2.5, 4.0).clamp(35, 99).toDouble(),
          mechanicsScore: mechanics,
          trajectory: _trajectory(releaseAngle.toDouble(), lateral, result),
          phases: _phases(mechanics),
        ),
      );

      elapsed += Duration(
        milliseconds:
            interval.inMilliseconds + (_random.nextInt(5200) - 2400),
      );
    }

    return shots;
  }

  ShotOutcomeDetail _missDetail(double mechanics) {
    final options = lateralBias.abs() > 3
        ? (lateralBias < 0
            ? [
                ShotOutcomeDetail.leftRim,
                ShotOutcomeDetail.leftRim,
                ShotOutcomeDetail.frontRim,
                ShotOutcomeDetail.short,
              ]
            : [
                ShotOutcomeDetail.rightRim,
                ShotOutcomeDetail.rightRim,
                ShotOutcomeDetail.backRim,
                ShotOutcomeDetail.long,
              ])
        : [
            ShotOutcomeDetail.frontRim,
            ShotOutcomeDetail.backRim,
            ShotOutcomeDetail.short,
            ShotOutcomeDetail.long,
          ];
    if (mechanics < 52 && _random.nextDouble() < 0.18) {
      return ShotOutcomeDetail.airball;
    }
    return options[_random.nextInt(options.length)];
  }

  /// Normalised ball path in the shot-detail viewport. x runs from the release
  /// hand to the rim, y is inverted screen space where 0 is the top.
  List<Offset> _trajectory(double releaseAngle, double lateral,
      ShotResult result) {
    const steps = 34;
    final arcHeight = 0.52 + (releaseAngle - 50) * 0.012;
    final overshoot = result == ShotResult.made ? 0.0 : lateral / 260;
    return List<Offset>.generate(steps, (i) {
      final t = i / (steps - 1);
      final x = 0.08 + t * 0.84 + overshoot * t * t;
      final y = 0.82 - (4 * arcHeight * t * (1 - t)) - t * 0.14;
      return Offset(x, y.clamp(0.02, 0.98));
    });
  }

  List<ShotPhase> _phases(double mechanics) {
    final crisp = mechanics > 80;
    var cursor = 0;
    ShotPhase step(String name, int duration) {
      final phase =
          ShotPhase(name: name, startMs: cursor, durationMs: duration);
      cursor += duration;
      return phase;
    }

    return [
      step('Ready', 180),
      step('Ball pickup', 120),
      step('Dip', crisp ? 128 : 168),
      step('Load', crisp ? 152 : 196),
      step('Upward motion', 142),
      step('Set point', crisp ? 88 : 122),
      step('Release', 46),
      step('Follow-through', crisp ? 690 : 520),
      step('Landing', 210),
      step('Recovery', 260),
    ];
  }
}
