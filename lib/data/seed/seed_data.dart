import 'dart:math' as math;

import '../../core/theme/av_colors.dart';
import '../models/confidence.dart';
import '../models/profile.dart';
import '../models/program.dart';
import '../models/progress.dart';
import '../models/session.dart';
import '../models/shot.dart';
import '../models/subscription.dart';
import 'drill_catalog.dart';
import 'shot_factory.dart';

/// Deterministic starting state for the application.
///
/// Everything here is shaped exactly like the payloads the session, coach and
/// subscription services return, so the presentation layer never needs to know
/// whether it is reading a live response or a locally restored snapshot.
abstract final class SeedData {
  static final DateTime today = _atNine(DateTime(2026, 7, 29));

  static DateTime _atNine(DateTime day) =>
      DateTime(day.year, day.month, day.day, 9, 0);

  static DateTime daysAgo(int days) => today.subtract(Duration(days: days));

  // ------------------------------------------------------------- profile --
  static const PlayerProfile player = PlayerProfile(
    id: 'player-nova-reyes',
    displayName: 'Nova Reyes',
    initials: 'NR',
    ageBand: '16 to 17',
    heightCm: 185,
    wingspanCm: 191,
    dominantHand: DominantHand.right,
    position: PlayerPosition.shootingGuard,
    skillLevel: SkillLevel.advanced,
    teamName: 'Northgate Prep Varsity',
    coachName: 'Coach Adrienne Ba',
    accentColor: AvColors.flare,
    goals: [
      'Raise catch-and-shoot three-point accuracy',
      'Hold follow-through through fatigue',
      'Reduce left drift on wing threes',
    ],
    weeklyAvailability: 5,
    isMinor: true,
    guardianName: 'Marisol Reyes',
  );

  // ------------------------------------------------------------ sessions --
  static final List<TrainingSession> sessions = _buildSessions();

  static TrainingSession get latestSession => sessions.first;

  static TrainingSession sessionById(String id) =>
      sessions.firstWhere((s) => s.id == id, orElse: () => sessions.first);

  static List<TrainingSession> _buildSessions() {
    final specs = <_SessionSpec>[
      _SessionSpec(
        id: 'session-2026-07-29',
        drillId: 'three-point',
        startedAt: today.add(const Duration(hours: 8, minutes: 10)),
        seed: 7291,
        shotCount: 48,
        baseAccuracy: 0.47,
        mechanics: 84.6,
        lateralBias: -4.8,
        releaseAngle: 51.4,
        calibration: 0.91,
        angle: CameraAngle.side,
        court: 'Northgate Prep — Main Gym',
        device: 'iPhone 17 Pro',
        onDevice: true,
      ),
      _SessionSpec(
        id: 'session-2026-07-27',
        drillId: 'free-throws',
        startedAt: daysAgo(2).add(const Duration(hours: 9, minutes: 25)),
        seed: 7272,
        shotCount: 50,
        baseAccuracy: 0.68,
        mechanics: 86.2,
        lateralBias: -2.1,
        releaseAngle: 52.8,
        calibration: 0.94,
        angle: CameraAngle.side,
        court: 'Northgate Prep — Main Gym',
        device: 'iPhone 17 Pro',
        onDevice: true,
      ),
      _SessionSpec(
        id: 'session-2026-07-25',
        drillId: 'catch-and-shoot',
        startedAt: daysAgo(4).add(const Duration(hours: 17, minutes: 40)),
        seed: 7253,
        shotCount: 40,
        baseAccuracy: 0.44,
        mechanics: 81.9,
        lateralBias: -6.4,
        releaseAngle: 50.2,
        calibration: 0.78,
        angle: CameraAngle.diagonal,
        court: 'Rowan Park — Outdoor Court 2',
        device: 'iPhone 17 Pro',
        onDevice: true,
      ),
      _SessionSpec(
        id: 'session-2026-07-22',
        drillId: 'pull-up',
        startedAt: daysAgo(7).add(const Duration(hours: 16, minutes: 5)),
        seed: 7224,
        shotCount: 40,
        baseAccuracy: 0.42,
        mechanics: 80.4,
        lateralBias: -5.9,
        releaseAngle: 49.6,
        calibration: 0.86,
        angle: CameraAngle.side,
        court: 'Northgate Prep — Auxiliary Gym',
        device: 'iPhone 17 Pro',
        onDevice: true,
      ),
      _SessionSpec(
        id: 'session-2026-07-19',
        drillId: 'five-spot',
        startedAt: daysAgo(10).add(const Duration(hours: 10, minutes: 15)),
        seed: 7195,
        shotCount: 25,
        baseAccuracy: 0.52,
        mechanics: 82.8,
        lateralBias: -3.2,
        releaseAngle: 50.9,
        calibration: 0.89,
        angle: CameraAngle.diagonal,
        court: 'Northgate Prep — Main Gym',
        device: 'iPhone 17 Pro',
        onDevice: false,
      ),
      _SessionSpec(
        id: 'session-2026-07-16',
        drillId: 'form-shooting',
        startedAt: daysAgo(13).add(const Duration(hours: 7, minutes: 50)),
        seed: 7166,
        shotCount: 50,
        baseAccuracy: 0.74,
        mechanics: 88.1,
        lateralBias: -1.4,
        releaseAngle: 53.1,
        calibration: 0.96,
        angle: CameraAngle.front,
        court: 'Northgate Prep — Main Gym',
        device: 'iPhone 17 Pro',
        onDevice: true,
      ),
    ];

    return specs.map(_materialise).toList(growable: false);
  }

  static TrainingSession _materialise(_SessionSpec spec) {
    final drill = DrillCatalog.byId(spec.drillId);
    final factory = ShotFactory(
      seed: spec.seed,
      baseAccuracy: spec.baseAccuracy,
      mechanicsCentre: spec.mechanics,
      lateralBias: spec.lateralBias,
      releaseAngleCentre: spec.releaseAngle,
    );

    final shots = factory.build(
      sessionId: spec.id,
      zones: drill.zones,
      type: drill.shotType,
      count: spec.shotCount,
      calibrationQuality: spec.calibration,
    );

    final duration = shots.isEmpty
        ? const Duration(minutes: 12)
        : shots.last.offsetFromStart + const Duration(seconds: 42);

    return TrainingSession(
      id: spec.id,
      drillId: drill.id,
      drillName: drill.name,
      startedAt: spec.startedAt,
      duration: duration,
      shots: shots,
      calibration: CalibrationRecord(
        angle: spec.angle,
        qualityScore: spec.calibration,
        courtProfile: spec.court,
        rimHeightM: 3.05,
        lightingScore: (spec.calibration - 0.04).clamp(0, 1),
        stabilityScore: (spec.calibration + 0.03).clamp(0, 1),
        framingScore: (spec.calibration - 0.01).clamp(0, 1),
        frameRate: spec.calibration > 0.85 ? 60 : 30,
        notes: spec.calibration > 0.85
            ? const ['Court plane locked from three visible lines.']
            : const [
                'Outdoor lighting varied during the session.',
                'Rim occluded on two attempts by a passing player.',
              ],
      ),
      cues: _cuesFor(spec, shots),
      modelVersion: 'det-1.4.2 / pose-2.1.0 / event-3.0.1',
      deviceName: spec.device,
      processedOnDevice: spec.onDevice,
    );
  }

  static List<CoachingCue> _cuesFor(_SessionSpec spec, List<Shot> shots) {
    final misses =
        shots.where((s) => s.result == ShotResult.missed).toList();
    final avgLateral = misses.isEmpty
        ? 0.0
        : misses.map((s) => s.lateralDeviationCm).reduce((a, b) => a + b) /
            misses.length;
    final drift = avgLateral.abs().toStringAsFixed(0);
    final side = avgLateral < 0 ? 'left' : 'right';

    return [
      CoachingCue(
        id: '${spec.id}-cue-1',
        headline: 'Your misses landed $drift cm $side of centre',
        detail:
            'Across ${misses.length} misses the ball crossed the rim plane $drift centimetres to the $side. '
            'Your elbow sat outside the shooting line on the same attempts, which is the most likely cause. '
            'Bring the elbow under the ball at set point before changing anything else.',
        source: CueSource.measurement,
        priority: CuePriority.primary,
        confidence: ConfidenceLevel.high,
        evidence: [
          'Left-right deviation on ${misses.length} misses',
          'Elbow flare measured at set point',
          'Camera placement eligible for alignment metrics',
        ],
        suggestedDrillId: 'form-shooting',
      ),
      CoachingCue(
        id: '${spec.id}-cue-2',
        headline: 'Release timing held steady through the session',
        detail:
            'Release time varied by 41 milliseconds between your first and last ten attempts, '
            'inside the 60 millisecond band you have held for three weeks.',
        source: CueSource.trend,
        priority: CuePriority.reinforcement,
        confidence: ConfidenceLevel.high,
        evidence: ['Release timing per attempt', 'Three-week rolling baseline'],
      ),
      CoachingCue(
        id: '${spec.id}-cue-3',
        headline: 'Knee flexion dropped after attempt 30',
        detail:
            'Average knee flexion fell from 128 to 121 degrees in the final third. '
            'Shorter legs into the shot usually shows up as front-rim misses within two sessions.',
        source: CueSource.measurement,
        priority: CuePriority.supporting,
        confidence: ConfidenceLevel.medium,
        evidence: ['Knee flexion per attempt', 'Front-rim miss share'],
        suggestedDrillId: 'fatigue-shooting',
      ),
      CoachingCue(
        id: '${spec.id}-cue-4',
        headline: 'Keep the finish held one extra beat on wing threes',
        detail:
            'Watched your wing attempts from Monday. The hand drops before the ball reaches the rim on the ones you rush. '
            'Hold it until you hear the net.',
        source: CueSource.humanCoach,
        priority: CuePriority.supporting,
        confidence: ConfidenceLevel.high,
        authorName: 'Coach Adrienne Ba',
      ),
    ];
  }

  // ------------------------------------------------------------ progress --
  static final List<ProgressPoint> progress = _buildProgress();

  static List<ProgressPoint> _buildProgress() {
    final random = math.Random(4471);
    final points = <ProgressPoint>[];
    for (var i = 179; i >= 0; i--) {
      final date = daysAgo(i);
      final weekday = date.weekday;
      final trains = weekday != DateTime.sunday && random.nextDouble() < 0.72;
      if (!trains) {
        points.add(
          ProgressPoint(
            date: date,
            attempts: 0,
            makes: 0,
            mechanicsScore: 0,
            consistencyScore: 0,
            averageEntryAngle: 0,
            calibrationQuality: 0,
          ),
        );
        continue;
      }

      final maturity = (179 - i) / 179;
      final attempts = 28 + random.nextInt(34);
      final rate = (0.372 + maturity * 0.098 + (random.nextDouble() - 0.5) * 0.09)
          .clamp(0.24, 0.68);
      final makes = (attempts * rate).round();

      points.add(
        ProgressPoint(
          date: date,
          attempts: attempts,
          makes: makes,
          mechanicsScore:
              (76.5 + maturity * 9.4 + (random.nextDouble() - 0.5) * 4.2)
                  .clamp(60, 96),
          consistencyScore:
              (68.0 + maturity * 14.5 + (random.nextDouble() - 0.5) * 6.0)
                  .clamp(50, 97),
          averageEntryAngle:
              43.2 + maturity * 2.1 + (random.nextDouble() - 0.5) * 1.8,
          calibrationQuality:
              (0.80 + maturity * 0.11 + (random.nextDouble() - 0.5) * 0.09)
                  .clamp(0.55, 0.98),
        ),
      );
    }
    return points;
  }

  static List<ProgressPoint> progressFor(TrendRange range) {
    final cutoff = today.subtract(Duration(days: range.days));
    return progress
        .where((p) => !p.date.isBefore(cutoff))
        .toList(growable: false);
  }

  static final List<PersonalRecord> records = [
    PersonalRecord(
      label: 'Best free-throw streak',
      value: '23',
      unit: 'consecutive makes',
      achievedAt: daysAgo(2),
      context: 'Free Throws, Northgate Prep Main Gym',
      verified: true,
    ),
    PersonalRecord(
      label: 'Highest session three-point rate',
      value: '52.1',
      unit: 'percent on 48 attempts',
      achievedAt: today,
      context: 'Three-Point, side placement, high confidence',
      verified: true,
    ),
    PersonalRecord(
      label: 'Best mechanics score',
      value: '92',
      unit: 'of 100',
      achievedAt: daysAgo(13),
      context: 'Form Shooting, front placement',
      verified: true,
    ),
    PersonalRecord(
      label: 'Most attempts in one session',
      value: '74',
      unit: 'attempts',
      achievedAt: daysAgo(24),
      context: 'Timed Shooting, diagonal placement',
      verified: true,
    ),
    PersonalRecord(
      label: 'Longest swish run',
      value: '7',
      unit: 'clean makes',
      achievedAt: daysAgo(31),
      context: 'Swish Challenge, rear placement',
      verified: false,
    ),
  ];

  static final List<TrendExplanation> explanations = [
    TrendExplanation(
      metric: 'Three-point percentage',
      change: 4.8,
      summary:
          'Real improvement. The gain survives when low-confidence attempts and the change of court are removed.',
      contributingFactors: [
        'Entry angle moved from 42.1 to 44.3 degrees',
        'Left drift on wing threes reduced by 3.1 cm',
        'Attempt volume rose 18 percent over the period',
      ],
      sampleSize: 412,
      attributedToSetup: 0.12,
    ),
    TrendExplanation(
      metric: 'Mechanics score',
      change: 2.1,
      summary:
          'Partly setup. Nearly half the movement follows the switch from diagonal to side placement, which measures elbow angle more accurately.',
      contributingFactors: [
        'Side placement used in 71 percent of recent sessions',
        'Follow-through duration up 84 milliseconds',
        'Knee flexion unchanged',
      ],
      sampleSize: 268,
      attributedToSetup: 0.46,
    ),
    TrendExplanation(
      metric: 'Consistency score',
      change: -1.4,
      summary:
          'Not significant. The sample is small and the movement sits inside normal week-to-week variation.',
      contributingFactors: [
        'Only 96 attempts in the comparison window',
        'One outdoor session with medium calibration',
      ],
      sampleSize: 96,
      attributedToSetup: 0.28,
    ),
  ];

  // ---------------------------------------------------------------- plan --
  static final TrainingPlan plan = TrainingPlan(
    id: 'plan-2026-w31',
    name: 'Alignment and range week',
    rationale:
        'Built from the last 14 sessions. Left drift on wing threes is the largest single cost to your percentage, '
        'so three of five sessions isolate elbow alignment before adding range and movement back in.',
    weekStart: daysAgo(3),
    authoredBy: 'ArcVanta coaching engine, reviewed by Coach Adrienne Ba',
    targetMetric: 'Wing three-point percentage',
    targetValue: 42,
    currentValue: 36.4,
    days: [
      PlanDay(
        date: daysAgo(3),
        kind: PlanDayKind.session,
        title: 'Alignment reset',
        focus: 'Elbow under the ball at set point',
        drillIds: ['form-shooting', 'spot-shooting'],
        estimatedMinutes: 34,
        completed: true,
      ),
      PlanDay(
        date: daysAgo(2),
        kind: PlanDayKind.session,
        title: 'Line routine',
        focus: 'Repeatable pre-shot routine and follow-through hold',
        drillIds: ['free-throws'],
        estimatedMinutes: 14,
        completed: true,
      ),
      PlanDay(
        date: daysAgo(1),
        kind: PlanDayKind.recovery,
        title: 'Light recovery',
        focus: 'Movement quality only, no scored shooting',
        drillIds: [],
        estimatedMinutes: 20,
        completed: true,
      ),
      PlanDay(
        date: today,
        kind: PlanDayKind.session,
        title: 'Range under control',
        focus: 'Hold the corrected release across the arc',
        drillIds: ['three-point', 'corner-three'],
        estimatedMinutes: 36,
        completed: true,
      ),
      PlanDay(
        date: today.add(const Duration(days: 1)),
        kind: PlanDayKind.session,
        title: 'Movement into range',
        focus: 'Plant order and stop balance before the catch',
        drillIds: ['catch-and-shoot', 'five-spot'],
        estimatedMinutes: 29,
        completed: false,
      ),
      PlanDay(
        date: today.add(const Duration(days: 2)),
        kind: PlanDayKind.session,
        title: 'Load tolerance',
        focus: 'Keep knee flexion above 124 degrees late in the set',
        drillIds: ['fatigue-shooting'],
        estimatedMinutes: 24,
        completed: false,
      ),
      PlanDay(
        date: today.add(const Duration(days: 3)),
        kind: PlanDayKind.rest,
        title: 'Rest',
        focus: 'No scheduled work',
        drillIds: [],
        estimatedMinutes: 0,
        completed: false,
      ),
    ],
  );

  // --------------------------------------------------------------- goals --
  static final List<Goal> goals = [
    Goal(
      id: 'goal-wing-three',
      kind: GoalKind.percentage,
      title: 'Wing three-point accuracy',
      detail:
          'Verified attempts only, measured across sessions with high or medium calibration confidence.',
      current: 36.4,
      target: 42,
      unit: '%',
      dueAt: today.add(const Duration(days: 24)),
      setBy: 'Coach Adrienne Ba',
    ),
    Goal(
      id: 'goal-volume',
      kind: GoalKind.volume,
      title: 'Weekly attempt volume',
      detail: 'Total counted attempts across all drills this week.',
      current: 218,
      target: 300,
      unit: ' attempts',
      dueAt: today.add(const Duration(days: 3)),
      setBy: 'Nova Reyes',
    ),
    Goal(
      id: 'goal-drift',
      kind: GoalKind.mechanics,
      title: 'Reduce left drift under 3 cm',
      detail:
          'Average left-right deviation on missed wing threes, front or diagonal placement required.',
      current: 4.8,
      target: 3,
      unit: ' cm',
      dueAt: today.add(const Duration(days: 17)),
      setBy: 'ArcVanta coaching engine',
    ),
    Goal(
      id: 'goal-consistency',
      kind: GoalKind.consistency,
      title: 'Shot-to-shot consistency',
      detail: 'Mechanical variance across a full session, higher is better.',
      current: 81.2,
      target: 88,
      unit: '',
      dueAt: today.add(const Duration(days: 45)),
      setBy: 'Nova Reyes',
    ),
    Goal(
      id: 'goal-ft-streak',
      kind: GoalKind.streak,
      title: 'Free-throw streak',
      detail: 'Best consecutive verified makes from the line.',
      current: 23,
      target: 25,
      unit: '',
      dueAt: today.add(const Duration(days: 31)),
      setBy: 'Nova Reyes',
    ),
  ];

  // ---------------------------------------------------------- highlights --
  static final List<Highlight> highlights = [
    Highlight(
      id: 'hl-best-makes-0729',
      title: 'Best makes — Three-Point',
      kind: HighlightKind.bestMakes,
      createdAt: today.add(const Duration(hours: 9, minutes: 12)),
      duration: const Duration(seconds: 48),
      clipCount: 12,
      sessionId: 'session-2026-07-29',
      visibility: HighlightVisibility.coachAndGuardian,
      accent: AvColors.flare,
      metricsBurnedIn: true,
    ),
    Highlight(
      id: 'hl-progress-july',
      title: 'July release comparison',
      kind: HighlightKind.progressComparison,
      createdAt: daysAgo(1),
      duration: const Duration(seconds: 36),
      clipCount: 6,
      sessionId: 'session-2026-07-29',
      visibility: HighlightVisibility.privateOnly,
      accent: AvColors.insight,
      metricsBurnedIn: true,
    ),
    Highlight(
      id: 'hl-coach-review-0727',
      title: 'Coach review — Free Throws',
      kind: HighlightKind.coachReview,
      createdAt: daysAgo(2),
      duration: const Duration(minutes: 2, seconds: 14),
      clipCount: 9,
      sessionId: 'session-2026-07-27',
      visibility: HighlightVisibility.coachAndGuardian,
      accent: AvColors.court,
      metricsBurnedIn: false,
    ),
    Highlight(
      id: 'hl-recap-0725',
      title: 'Session recap — Catch-and-Shoot',
      kind: HighlightKind.sessionRecap,
      createdAt: daysAgo(4),
      duration: const Duration(minutes: 1, seconds: 5),
      clipCount: 18,
      sessionId: 'session-2026-07-25',
      visibility: HighlightVisibility.privateOnly,
      accent: AvColors.made,
      metricsBurnedIn: true,
    ),
  ];

  // ------------------------------------------------------------ coaching --
  static final List<AthleteSummary> roster = [
    AthleteSummary(
      id: 'player-nova-reyes',
      name: 'Nova Reyes',
      initials: 'NR',
      ageBand: '16 to 17',
      position: PlayerPosition.shootingGuard,
      accentColor: AvColors.flare,
      sessionsThisWeek: 4,
      percentage: 47.9,
      percentageDelta: 4.8,
      mechanicsScore: 84.6,
      pendingReviews: 1,
      lastSessionAt: today.add(const Duration(hours: 8, minutes: 10)),
      assignmentsComplete: 3,
      assignmentsTotal: 4,
      guardianApproved: true,
      focusArea: 'Left drift on wing threes',
    ),
    AthleteSummary(
      id: 'player-idris-kane',
      name: 'Idris Kane',
      initials: 'IK',
      ageBand: '17 to 18',
      position: PlayerPosition.pointGuard,
      accentColor: AvColors.insight,
      sessionsThisWeek: 5,
      percentage: 44.2,
      percentageDelta: 1.6,
      mechanicsScore: 81.0,
      pendingReviews: 2,
      lastSessionAt: daysAgo(1).add(const Duration(hours: 18)),
      assignmentsComplete: 4,
      assignmentsTotal: 4,
      guardianApproved: true,
      focusArea: 'Gather timing off the dribble',
    ),
    AthleteSummary(
      id: 'player-thea-lindqvist',
      name: 'Thea Lindqvist',
      initials: 'TL',
      ageBand: '15 to 16',
      position: PlayerPosition.smallForward,
      accentColor: AvColors.court,
      sessionsThisWeek: 2,
      percentage: 39.6,
      percentageDelta: -2.3,
      mechanicsScore: 77.4,
      pendingReviews: 0,
      lastSessionAt: daysAgo(3).add(const Duration(hours: 16, minutes: 30)),
      assignmentsComplete: 1,
      assignmentsTotal: 3,
      guardianApproved: false,
      focusArea: 'Set-point height consistency',
    ),
    AthleteSummary(
      id: 'player-marcus-oyelaran',
      name: 'Marcus Oyelaran',
      initials: 'MO',
      ageBand: '17 to 18',
      position: PlayerPosition.powerForward,
      accentColor: AvColors.made,
      sessionsThisWeek: 3,
      percentage: 51.8,
      percentageDelta: 3.1,
      mechanicsScore: 86.9,
      pendingReviews: 1,
      lastSessionAt: daysAgo(1).add(const Duration(hours: 7, minutes: 20)),
      assignmentsComplete: 2,
      assignmentsTotal: 3,
      guardianApproved: true,
      focusArea: 'Range extension to the arc',
    ),
    AthleteSummary(
      id: 'player-june-ashworth',
      name: 'June Ashworth',
      initials: 'JA',
      ageBand: '16 to 17',
      position: PlayerPosition.center,
      accentColor: AvColors.caution,
      sessionsThisWeek: 1,
      percentage: 42.7,
      percentageDelta: 0.4,
      mechanicsScore: 79.2,
      pendingReviews: 3,
      lastSessionAt: daysAgo(5).add(const Duration(hours: 15)),
      assignmentsComplete: 0,
      assignmentsTotal: 2,
      guardianApproved: true,
      focusArea: 'Free-throw routine repeatability',
    ),
    AthleteSummary(
      id: 'player-sami-oduya',
      name: 'Sami Oduya',
      initials: 'SO',
      ageBand: '15 to 16',
      position: PlayerPosition.shootingGuard,
      accentColor: AvColors.miss,
      sessionsThisWeek: 4,
      percentage: 37.1,
      percentageDelta: 5.2,
      mechanicsScore: 74.8,
      pendingReviews: 0,
      lastSessionAt: daysAgo(2).add(const Duration(hours: 17, minutes: 45)),
      assignmentsComplete: 3,
      assignmentsTotal: 3,
      guardianApproved: true,
      focusArea: 'Guide-hand separation',
    ),
  ];

  static final List<Assignment> assignments = [
    Assignment(
      id: 'as-1',
      drillId: 'form-shooting',
      drillName: 'Form Shooting',
      athleteId: 'player-nova-reyes',
      athleteName: 'Nova Reyes',
      assignedBy: 'Coach Adrienne Ba',
      dueAt: today.add(const Duration(days: 1)),
      status: AssignmentStatus.inProgress,
      targetMakes: 45,
      completedMakes: 31,
      note: 'Front placement only. I want to see the elbow line clearly.',
    ),
    Assignment(
      id: 'as-2',
      drillId: 'corner-three',
      drillName: 'Corner Three',
      athleteId: 'player-nova-reyes',
      athleteName: 'Nova Reyes',
      assignedBy: 'Coach Adrienne Ba',
      dueAt: today.add(const Duration(days: 3)),
      status: AssignmentStatus.assigned,
      targetMakes: 16,
      completedMakes: 0,
      note: 'Both corners, equal volume. Watch the baseline foot.',
    ),
    Assignment(
      id: 'as-3',
      drillId: 'free-throws',
      drillName: 'Free Throws',
      athleteId: 'player-idris-kane',
      athleteName: 'Idris Kane',
      assignedBy: 'Coach Adrienne Ba',
      dueAt: daysAgo(1),
      status: AssignmentStatus.submitted,
      targetMakes: 40,
      completedMakes: 40,
      note: 'Post the run when you finish so I can review the routine.',
    ),
    Assignment(
      id: 'as-4',
      drillId: 'spot-shooting',
      drillName: 'Spot Shooting',
      athleteId: 'player-thea-lindqvist',
      athleteName: 'Thea Lindqvist',
      assignedBy: 'Coach Adrienne Ba',
      dueAt: daysAgo(2),
      status: AssignmentStatus.overdue,
      targetMakes: 25,
      completedMakes: 9,
      note: 'Guardian approval still pending for cloud review.',
    ),
    Assignment(
      id: 'as-5',
      drillId: 'fatigue-shooting',
      drillName: 'Fatigue Shooting',
      athleteId: 'player-marcus-oyelaran',
      athleteName: 'Marcus Oyelaran',
      assignedBy: 'Coach Adrienne Ba',
      dueAt: today.add(const Duration(days: 2)),
      status: AssignmentStatus.reviewed,
      targetMakes: 18,
      completedMakes: 18,
      note: 'Good hold on knee flexion. Next block adds movement.',
    ),
  ];

  // -------------------------------------------------------- notifications --
  static final List<AppNotification> notifications = [
    AppNotification(
      id: 'n-1',
      kind: NotificationKind.assignment,
      title: 'Coach Adrienne Ba reviewed your free-throw session',
      body:
          'Two timestamped notes on your pre-shot routine and one on follow-through hold.',
      createdAt: today.add(const Duration(hours: 10, minutes: 42)),
      read: false,
      actionLabel: 'Open review',
      actionRoute: '/sessions/session-2026-07-27',
    ),
    AppNotification(
      id: 'n-2',
      kind: NotificationKind.progress,
      title: 'Personal record: highest session three-point rate',
      body: '52.1 percent on 48 verified attempts this morning.',
      createdAt: today.add(const Duration(hours: 9, minutes: 15)),
      read: false,
      actionLabel: 'View session',
      actionRoute: '/sessions/session-2026-07-29',
    ),
    AppNotification(
      id: 'n-3',
      kind: NotificationKind.analysis,
      title: 'Advanced cloud analysis finished',
      body:
          'Multi-player pose analysis completed for the Rowan Park session. Source video expires in 12 days.',
      createdAt: daysAgo(1).add(const Duration(hours: 20, minutes: 4)),
      read: true,
      actionLabel: 'View results',
      actionRoute: '/sessions/session-2026-07-25',
    ),
    AppNotification(
      id: 'n-4',
      kind: NotificationKind.training,
      title: 'Movement into range is scheduled for tomorrow',
      body: 'Catch-and-Shoot then Five-Spot Challenge, about 29 minutes.',
      createdAt: daysAgo(1).add(const Duration(hours: 18)),
      read: true,
      actionLabel: 'Open plan',
      actionRoute: '/plan',
    ),
    AppNotification(
      id: 'n-5',
      kind: NotificationKind.safety,
      title: 'Guardian approval recorded',
      body:
          'Marisol Reyes approved coach access for Northgate Prep Varsity until the end of the season.',
      createdAt: daysAgo(3).add(const Duration(hours: 11, minutes: 30)),
      read: true,
    ),
    AppNotification(
      id: 'n-6',
      kind: NotificationKind.account,
      title: 'Player Pro renews on 12 August',
      body: 'Annual plan, verified through the App Store.',
      createdAt: daysAgo(5).add(const Duration(hours: 8)),
      read: true,
      actionLabel: 'Manage plan',
      actionRoute: '/subscription',
    ),
  ];

  // -------------------------------------------------------- subscription --
  static const List<PlanOption> plans = [
    PlanOption(
      tier: PlanTier.free,
      tagline: 'Count shots and check your setup at no cost.',
      monthlyPrice: 0,
      annualPrice: 0,
      features: [
        'Eight live sessions each month',
        'Makes, attempts and percentage',
        'Standard drill library',
        'On-device processing',
      ],
      limits: [
        'Thirty days of history',
        'No mechanics metrics',
        'No coach sharing',
      ],
    ),
    PlanOption(
      tier: PlanTier.playerPro,
      tagline: 'Full mechanics, trends and automatic highlights.',
      monthlyPrice: 14.99,
      annualPrice: 119.99,
      features: [
        'Unlimited supported sessions',
        'Complete mechanics and ball-flight metrics',
        'Shot charts, heatmaps and trend explanations',
        'Personalised training plans',
        'Video import and side-by-side comparison',
        'Automatic highlights and export',
        'Full history with encrypted sync',
      ],
      limits: [],
      trialDays: 14,
      recommended: true,
    ),
    PlanOption(
      tier: PlanTier.coachPro,
      tagline: 'Roster, assignments and review workflow.',
      monthlyPrice: 39.99,
      annualPrice: 359.99,
      features: [
        'Everything in Player Pro',
        'Athlete roster up to 30 players',
        'Drill assignments with due dates',
        'Session review queue and annotations',
        'Athlete and team reports',
        'CSV and PDF export',
      ],
      limits: ['Thirty athletes per coach seat'],
      trialDays: 14,
    ),
    PlanOption(
      tier: PlanTier.academy,
      tagline: 'Multiple coaches, teams and central administration.',
      monthlyPrice: 149.99,
      annualPrice: 1439.99,
      features: [
        'Everything in Coach Pro',
        'Unlimited coaches and teams',
        'Organisation administration and branding',
        'Shared drill templates',
        'Team analytics with minimum-data protection',
        'Central billing and configurable retention',
      ],
      limits: [],
    ),
  ];

  static final Entitlement entitlement = Entitlement(
    tier: PlanTier.playerPro,
    state: EntitlementState.active,
    period: BillingPeriod.annual,
    renewsAt: DateTime(2026, 8, 12),
    store: 'App Store',
    verifiedServerSide: true,
  );

  // ---------------------------------------------------------- device info --
  static const List<String> courtProfiles = [
    'Northgate Prep — Main Gym',
    'Northgate Prep — Auxiliary Gym',
    'Rowan Park — Outdoor Court 2',
    'Halvorsen Community Center',
  ];
}

class _SessionSpec {
  const _SessionSpec({
    required this.id,
    required this.drillId,
    required this.startedAt,
    required this.seed,
    required this.shotCount,
    required this.baseAccuracy,
    required this.mechanics,
    required this.lateralBias,
    required this.releaseAngle,
    required this.calibration,
    required this.angle,
    required this.court,
    required this.device,
    required this.onDevice,
  });

  final String id;
  final String drillId;
  final DateTime startedAt;
  final int seed;
  final int shotCount;
  final double baseAccuracy;
  final double mechanics;
  final double lateralBias;
  final double releaseAngle;
  final double calibration;
  final CameraAngle angle;
  final String court;
  final String device;
  final bool onDevice;
}
