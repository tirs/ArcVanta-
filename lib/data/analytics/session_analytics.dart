import 'dart:math' as math;

import '../../core/utils/formatters.dart';
import '../models/progress.dart';
import '../models/session.dart';
import '../models/shot.dart';

/// Derives every trend, record and breakdown in the app from recorded
/// sessions.
///
/// Nothing here invents a number. If the shots do not support a statistic the
/// function returns nothing rather than a plausible-looking default, because a
/// fabricated trend is worse than a blank chart: the user cannot tell it apart
/// from a real one.
abstract final class SessionAnalytics {
  /// Below this many attempts a percentage is noise, and the app says so
  /// instead of drawing a line through it.
  static const int minimumAttemptsForTrend = 10;

  /// A record needs enough of a sample that one lucky session cannot set it.
  static const int minimumAttemptsForRecord = 10;

  /// One point per day the athlete actually trained, oldest first.
  ///
  /// Days off are omitted rather than plotted as zero. A rest day is not a
  /// day you shot nothing percent.
  static List<ProgressPoint> progressPoints(
    List<TrainingSession> sessions,
    TrendRange range, {
    required DateTime now,
  }) {
    final cutoff = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: range.days - 1));

    final byDay = <DateTime, List<TrainingSession>>{};
    for (final session in sessions) {
      final day = DateTime(
        session.startedAt.year,
        session.startedAt.month,
        session.startedAt.day,
      );
      if (day.isBefore(cutoff)) continue;
      (byDay[day] ??= <TrainingSession>[]).add(session);
    }

    final days = byDay.keys.toList()..sort();

    return [
      for (final day in days) _pointForDay(day, byDay[day]!),
    ];
  }

  static ProgressPoint _pointForDay(
    DateTime day,
    List<TrainingSession> sessions,
  ) {
    var attempts = 0;
    var makes = 0;
    for (final session in sessions) {
      attempts += session.attemptCount;
      makes += session.makeCount;
    }

    // Session-level scores are averaged by attempt count, so a two-shot warmup
    // does not weigh as much as a hundred-shot block.
    return ProgressPoint(
      date: day,
      attempts: attempts,
      makes: makes,
      mechanicsScore: _weightedAverage(
        sessions,
        (s) => s.averageMechanics,
      ),
      consistencyScore: _weightedAverage(sessions, (s) => s.consistencyScore),
      averageEntryAngle: _weightedAverage(sessions, (s) => s.averageEntryAngle),
      calibrationQuality: _weightedAverage(
        sessions,
        (s) => s.calibration.qualityScore,
      ),
    );
  }

  static double _weightedAverage(
    List<TrainingSession> sessions,
    double Function(TrainingSession) value,
  ) {
    var total = 0.0;
    var weight = 0;
    for (final session in sessions) {
      if (session.attemptCount == 0) continue;
      total += value(session) * session.attemptCount;
      weight += session.attemptCount;
    }
    return weight == 0 ? 0 : total / weight;
  }

  // --- Headline numbers ---------------------------------------------------

  static SessionTotals totals(
    List<TrainingSession> sessions, {
    DateTime? since,
  }) {
    var attempts = 0;
    var makes = 0;
    var count = 0;
    var duration = Duration.zero;

    for (final session in sessions) {
      if (since != null && session.startedAt.isBefore(since)) continue;
      count++;
      attempts += session.attemptCount;
      makes += session.makeCount;
      duration += session.duration;
    }

    return SessionTotals(
      sessions: count,
      attempts: attempts,
      makes: makes,
      duration: duration,
    );
  }

  /// Makes and attempts per zone across the given sessions.
  static Map<CourtZone, ZoneRecord> zoneBreakdown(
    List<TrainingSession> sessions,
  ) {
    final makes = <CourtZone, int>{};
    final attempts = <CourtZone, int>{};

    for (final session in sessions) {
      for (final shot in session.shots) {
        if (!shot.result.countsAsAttempt) continue;
        attempts[shot.zone] = (attempts[shot.zone] ?? 0) + 1;
        if (shot.isMake) makes[shot.zone] = (makes[shot.zone] ?? 0) + 1;
      }
    }

    return {
      for (final zone in attempts.keys)
        zone: ZoneRecord(makes[zone] ?? 0, attempts[zone]!),
    };
  }

  /// The longest run of makes across a single session.
  static int bestStreak(List<TrainingSession> sessions) {
    var best = 0;
    for (final session in sessions) {
      best = math.max(best, session.bestStreak);
    }
    return best;
  }

  // --- Records ------------------------------------------------------------

  /// Personal bests, each tied to the session that set it.
  ///
  /// Only records the shots can actually support are returned; a new user with
  /// one short session gets an empty list, not a page of bests set by nothing.
  static List<PersonalRecord> personalRecords(
    List<TrainingSession> sessions,
  ) {
    final eligible = [
      for (final session in sessions)
        if (session.attemptCount >= minimumAttemptsForRecord) session,
    ];
    if (eligible.isEmpty) return const [];

    final records = <PersonalRecord>[];

    final bestPercentage = _bestBy(eligible, (s) => s.percentage);
    if (bestPercentage != null) {
      records.add(
        PersonalRecord(
          label: 'Best session accuracy',
          value: bestPercentage.percentage.toStringAsFixed(0),
          unit: '%',
          achievedAt: bestPercentage.startedAt,
          context:
              '${bestPercentage.makeCount} of ${bestPercentage.attemptCount} '
              'in ${bestPercentage.drillName}',
          verified: bestPercentage.calibration.qualityScore >= 0.7,
        ),
      );
    }

    final streakSession = _bestBy(sessions, (s) => s.bestStreak.toDouble());
    if (streakSession != null && streakSession.bestStreak >= 3) {
      records.add(
        PersonalRecord(
          label: 'Longest make streak',
          value: '${streakSession.bestStreak}',
          unit: ' in a row',
          achievedAt: streakSession.startedAt,
          context: 'During ${streakSession.drillName}',
          verified: streakSession.calibration.qualityScore >= 0.7,
        ),
      );
    }

    final volumeSession = _bestBy(sessions, (s) => s.attemptCount.toDouble());
    if (volumeSession != null && volumeSession.attemptCount > 0) {
      records.add(
        PersonalRecord(
          label: 'Most attempts in a session',
          value: '${volumeSession.attemptCount}',
          unit: ' shots',
          achievedAt: volumeSession.startedAt,
          context: volumeSession.drillName,
          verified: true,
        ),
      );
    }

    final mechanics = _bestBy(eligible, (s) => s.averageMechanics);
    if (mechanics != null && mechanics.averageMechanics > 0) {
      records.add(
        PersonalRecord(
          label: 'Best mechanics score',
          value: mechanics.averageMechanics.toStringAsFixed(0),
          unit: '/100',
          achievedAt: mechanics.startedAt,
          context: 'Averaged over ${Fmt.count(mechanics.attemptCount, 'shot')}',
          verified: mechanics.calibration.qualityScore >= 0.7,
        ),
      );
    }

    return records;
  }

  static TrainingSession? _bestBy(
    List<TrainingSession> sessions,
    double Function(TrainingSession) score,
  ) {
    TrainingSession? best;
    var bestScore = double.negativeInfinity;
    for (final session in sessions) {
      final value = score(session);
      if (value > bestScore) {
        bestScore = value;
        best = session;
      }
    }
    return best;
  }

  // --- Trend explanations -------------------------------------------------

  /// Explains movement between the two most recent comparable blocks.
  ///
  /// The honesty requirement in the scope is the whole point of this function:
  /// when calibration quality changed between the blocks, part of any measured
  /// swing is the camera and not the shooter, and that share is reported rather
  /// than buried.
  static List<TrendExplanation> explainTrends(
    List<TrainingSession> sessions, {
    required DateTime now,
  }) {
    if (sessions.length < 2) return const [];

    final recent = <TrainingSession>[];
    final previous = <TrainingSession>[];
    final midpoint = sessions.length ~/ 2;
    for (var i = 0; i < sessions.length; i++) {
      // `sessions` is newest first.
      (i < midpoint ? recent : previous).add(sessions[i]);
    }

    if (recent.isEmpty || previous.isEmpty) return const [];

    final recentTotals = totals(recent);
    final previousTotals = totals(previous);
    if (recentTotals.attempts < minimumAttemptsForTrend ||
        previousTotals.attempts < minimumAttemptsForTrend) {
      return const [];
    }

    final explanations = <TrendExplanation>[];

    final accuracyChange =
        recentTotals.percentage - previousTotals.percentage;
    if (accuracyChange.abs() >= 0.5) {
      explanations.add(
        _explain(
          metric: 'Accuracy',
          change: accuracyChange,
          unit: 'points',
          recent: recent,
          previous: previous,
          sampleSize: recentTotals.attempts,
        ),
      );
    }

    final recentAngle = _weightedAverage(recent, (s) => s.averageEntryAngle);
    final previousAngle = _weightedAverage(
      previous,
      (s) => s.averageEntryAngle,
    );
    final angleChange = recentAngle - previousAngle;
    if (previousAngle > 0 && angleChange.abs() >= 0.5) {
      explanations.add(
        _explain(
          metric: 'Entry angle',
          change: angleChange,
          unit: 'degrees',
          recent: recent,
          previous: previous,
          sampleSize: recentTotals.attempts,
        ),
      );
    }

    return explanations;
  }

  static TrendExplanation _explain({
    required String metric,
    required double change,
    required String unit,
    required List<TrainingSession> recent,
    required List<TrainingSession> previous,
    required int sampleSize,
  }) {
    final recentQuality = _weightedAverage(
      recent,
      (s) => s.calibration.qualityScore,
    );
    final previousQuality = _weightedAverage(
      previous,
      (s) => s.calibration.qualityScore,
    );
    final qualityShift = (recentQuality - previousQuality).abs();

    // A calibration swing of a tenth is roughly where measured angles start to
    // move on their own, so that is the scale the attribution is read against.
    final attributedToSetup = (qualityShift / 0.1).clamp(0.0, 0.6);

    final factors = <String>[
      '${recent.length} recent sessions against ${previous.length} earlier',
      '$sampleSize attempts in the recent block',
    ];
    if (qualityShift >= 0.05) {
      factors.add(
        'Calibration quality moved '
        '${(qualityShift * 100).toStringAsFixed(0)} points between blocks',
      );
    }
    if (sampleSize < 30) {
      factors.add('Sample is small, so expect this to move');
    }

    final direction = change >= 0 ? 'up' : 'down';
    return TrendExplanation(
      metric: metric,
      change: change,
      summary:
          '$metric is $direction ${change.abs().toStringAsFixed(1)} $unit '
          'against your previous sessions.',
      contributingFactors: factors,
      sampleSize: sampleSize,
      attributedToSetup: attributedToSetup,
    );
  }
}

/// Aggregate counts over a set of sessions.
class SessionTotals {
  const SessionTotals({
    required this.sessions,
    required this.attempts,
    required this.makes,
    required this.duration,
  });

  static const SessionTotals empty = SessionTotals(
    sessions: 0,
    attempts: 0,
    makes: 0,
    duration: Duration.zero,
  );

  final int sessions;
  final int attempts;
  final int makes;
  final Duration duration;

  double get percentage => attempts == 0 ? 0 : makes / attempts * 100;
  bool get isEmpty => sessions == 0;

  /// Whether a percentage drawn from this many attempts is worth showing.
  bool get supportsPercentage =>
      attempts >= SessionAnalytics.minimumAttemptsForTrend;
}
