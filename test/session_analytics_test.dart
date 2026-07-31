import 'package:arcvanta/data/analytics/session_analytics.dart';
import 'package:arcvanta/data/models/confidence.dart';
import 'package:arcvanta/data/models/progress.dart';
import 'package:arcvanta/data/models/session.dart';
import 'package:arcvanta/data/models/shot.dart';
import 'package:flutter_test/flutter_test.dart';

/// The analytics used to be hand-written constants. These tests exist to make
/// sure they are now arithmetic over recorded shots, and in particular that
/// they decline to produce a number when the shots cannot support one.
void main() {
  Shot shot({
    required int index,
    required ShotResult result,
    CourtZone zone = CourtZone.freeThrow,
    double entryAngle = 45,
    double mechanics = 0.8,
  }) {
    return Shot(
      id: 'shot-$index-$zone',
      index: index,
      offsetFromStart: Duration(seconds: index * 10),
      result: result,
      outcomeDetail: ShotOutcomeDetail.undetermined,
      zone: zone,
      type: ShotType.setShot,
      confidence: ConfidenceLevel.high,
      releaseAngle: 52,
      entryAngle: entryAngle,
      apexHeightM: 3.8,
      releaseHeightM: 2.2,
      ballSpeedMs: 7,
      flightTimeMs: 900,
      lateralDeviationCm: 0,
      depthCm: 0,
      elbowAngle: 88,
      kneeFlexion: 120,
      guideHandSeparationCm: 3,
      releaseTimeMs: 600,
      followThroughMs: 400,
      landingDriftCm: 2,
      balanceScore: 0.8,
      mechanicsScore: mechanics,
      trajectory: const [],
      phases: const [],
    );
  }

  TrainingSession session({
    required String id,
    required DateTime startedAt,
    required List<Shot> shots,
    double calibration = 0.9,
    bool isDemo = false,
  }) {
    return TrainingSession(
      id: id,
      drillId: 'drill',
      drillName: 'Free throws',
      startedAt: startedAt,
      duration: const Duration(minutes: 20),
      shots: shots,
      calibration: CalibrationRecord(
        angle: CameraAngle.side,
        qualityScore: calibration,
        courtProfile: 'Gym',
        rimHeightM: 3.048,
        lightingScore: calibration,
        stabilityScore: calibration,
        framingScore: calibration,
        frameRate: 60,
        notes: const [],
      ),
      cues: const [],
      modelVersion: 'test',
      deviceName: 'test',
      processedOnDevice: true,
      isDemo: isDemo,
    );
  }

  List<Shot> makesAndMisses(int makes, int misses, {CourtZone? zone}) => [
    for (var i = 0; i < makes; i++)
      shot(
        index: i,
        result: ShotResult.made,
        zone: zone ?? CourtZone.freeThrow,
      ),
    for (var i = 0; i < misses; i++)
      shot(
        index: makes + i,
        result: ShotResult.missed,
        zone: zone ?? CourtZone.freeThrow,
      ),
  ];

  group('totals', () {
    test('an empty history totals to nothing rather than failing', () {
      final totals = SessionAnalytics.totals(const []);
      expect(totals.isEmpty, isTrue);
      expect(totals.attempts, 0);
      expect(totals.percentage, 0);
      expect(totals.supportsPercentage, isFalse);
    });

    test('makes and attempts are summed from the shots', () {
      final totals = SessionAnalytics.totals([
        session(
          id: 'a',
          startedAt: DateTime(2026, 5, 1),
          shots: makesAndMisses(7, 3),
        ),
        session(
          id: 'b',
          startedAt: DateTime(2026, 5, 2),
          shots: makesAndMisses(4, 6),
        ),
      ]);

      expect(totals.sessions, 2);
      expect(totals.attempts, 20);
      expect(totals.makes, 11);
      expect(totals.percentage, closeTo(55, 1e-9));
    });

    test('invalid shots are not counted as attempts', () {
      final totals = SessionAnalytics.totals([
        session(
          id: 'a',
          startedAt: DateTime(2026, 5, 1),
          shots: [
            shot(index: 0, result: ShotResult.made),
            shot(index: 1, result: ShotResult.invalid),
          ],
        ),
      ]);

      expect(totals.attempts, 1);
      expect(totals.makes, 1);
    });

    test('a since cutoff excludes older sessions', () {
      final sessions = [
        session(
          id: 'recent',
          startedAt: DateTime(2026, 5, 20),
          shots: makesAndMisses(5, 5),
        ),
        session(
          id: 'old',
          startedAt: DateTime(2026, 1, 1),
          shots: makesAndMisses(10, 0),
        ),
      ];

      final totals = SessionAnalytics.totals(
        sessions,
        since: DateTime(2026, 5, 1),
      );
      expect(totals.sessions, 1);
      expect(totals.makes, 5);
    });

    test('a small sample is flagged as not supporting a percentage', () {
      final totals = SessionAnalytics.totals([
        session(
          id: 'a',
          startedAt: DateTime(2026, 5, 1),
          shots: makesAndMisses(3, 0),
        ),
      ]);

      expect(totals.percentage, 100);
      expect(totals.supportsPercentage, isFalse);
    });
  });

  group('progress points', () {
    test('an empty history plots nothing', () {
      expect(
        SessionAnalytics.progressPoints(
          const [],
          TrendRange.week,
          now: DateTime(2026, 5, 20),
        ),
        isEmpty,
      );
    });

    test('sessions on the same day collapse into one point', () {
      final points = SessionAnalytics.progressPoints(
        [
          session(
            id: 'morning',
            startedAt: DateTime(2026, 5, 20, 9),
            shots: makesAndMisses(5, 5),
          ),
          session(
            id: 'evening',
            startedAt: DateTime(2026, 5, 20, 18),
            shots: makesAndMisses(8, 2),
          ),
        ],
        TrendRange.week,
        now: DateTime(2026, 5, 20, 21),
      );

      expect(points, hasLength(1));
      expect(points.single.attempts, 20);
      expect(points.single.makes, 13);
      expect(points.single.percentage, closeTo(65, 1e-9));
    });

    test('rest days are omitted, not plotted as zero', () {
      final points = SessionAnalytics.progressPoints(
        [
          session(
            id: 'a',
            startedAt: DateTime(2026, 5, 18),
            shots: makesAndMisses(5, 5),
          ),
          session(
            id: 'b',
            startedAt: DateTime(2026, 5, 20),
            shots: makesAndMisses(6, 4),
          ),
        ],
        TrendRange.week,
        now: DateTime(2026, 5, 20, 21),
      );

      expect(points, hasLength(2));
      expect(points.every((p) => p.attempts > 0), isTrue);
    });

    test('points are ordered oldest first', () {
      final points = SessionAnalytics.progressPoints(
        [
          session(
            id: 'b',
            startedAt: DateTime(2026, 5, 20),
            shots: makesAndMisses(6, 4),
          ),
          session(
            id: 'a',
            startedAt: DateTime(2026, 5, 18),
            shots: makesAndMisses(5, 5),
          ),
        ],
        TrendRange.week,
        now: DateTime(2026, 5, 20, 21),
      );

      expect(points.first.date.isBefore(points.last.date), isTrue);
    });

    test('sessions outside the range are dropped', () {
      final points = SessionAnalytics.progressPoints(
        [
          session(
            id: 'inside',
            startedAt: DateTime(2026, 5, 20),
            shots: makesAndMisses(5, 5),
          ),
          session(
            id: 'outside',
            startedAt: DateTime(2026, 1, 5),
            shots: makesAndMisses(5, 5),
          ),
        ],
        TrendRange.week,
        now: DateTime(2026, 5, 20),
      );

      expect(points, hasLength(1));
    });

    test('scores are weighted by attempts, not by session', () {
      final points = SessionAnalytics.progressPoints(
        [
          session(
            id: 'long',
            startedAt: DateTime(2026, 5, 20, 9),
            shots: [
              for (var i = 0; i < 90; i++)
                shot(index: i, result: ShotResult.made, mechanics: 0.9),
            ],
          ),
          session(
            id: 'short',
            startedAt: DateTime(2026, 5, 20, 18),
            shots: [
              for (var i = 0; i < 10; i++)
                shot(index: i, result: ShotResult.made, mechanics: 0.1),
            ],
          ),
        ],
        TrendRange.week,
        now: DateTime(2026, 5, 20, 21),
      );

      // A straight mean of the two sessions would be 0.5; weighting by the
      // ninety shots against ten gives 0.82.
      expect(points.single.mechanicsScore, closeTo(0.82, 1e-9));
    });
  });

  group('zone breakdown', () {
    test('shots are grouped by zone across sessions', () {
      final zones = SessionAnalytics.zoneBreakdown([
        session(
          id: 'a',
          startedAt: DateTime(2026, 5, 1),
          shots: [
            ...makesAndMisses(3, 1, zone: CourtZone.leftCorner3),
            ...makesAndMisses(1, 4, zone: CourtZone.paint),
          ],
        ),
      ]);

      expect(zones[CourtZone.leftCorner3]!.makes, 3);
      expect(zones[CourtZone.leftCorner3]!.attempts, 4);
      expect(zones[CourtZone.paint]!.percentage, closeTo(20, 1e-9));
    });

    test('zones with no shots are absent rather than zero', () {
      final zones = SessionAnalytics.zoneBreakdown([
        session(
          id: 'a',
          startedAt: DateTime(2026, 5, 1),
          shots: makesAndMisses(2, 2, zone: CourtZone.freeThrow),
        ),
      ]);

      expect(zones.keys, [CourtZone.freeThrow]);
      expect(zones.containsKey(CourtZone.topKey3), isFalse);
    });
  });

  group('personal records', () {
    test('a history too short to support a record produces none', () {
      final records = SessionAnalytics.personalRecords([
        session(
          id: 'a',
          startedAt: DateTime(2026, 5, 1),
          shots: makesAndMisses(3, 0),
        ),
      ]);

      expect(records, isEmpty);
    });

    test('no history at all produces no records', () {
      expect(SessionAnalytics.personalRecords(const []), isEmpty);
    });

    test('the best session sets the accuracy record', () {
      final records = SessionAnalytics.personalRecords([
        session(
          id: 'good',
          startedAt: DateTime(2026, 5, 10),
          shots: makesAndMisses(18, 2),
        ),
        session(
          id: 'bad',
          startedAt: DateTime(2026, 5, 12),
          shots: makesAndMisses(5, 15),
        ),
      ]);

      final accuracy = records.firstWhere(
        (r) => r.label == 'Best session accuracy',
      );
      expect(accuracy.value, '90');
      expect(accuracy.achievedAt, DateTime(2026, 5, 10));
      expect(accuracy.verified, isTrue);
    });

    test('a record set on a poor calibration is marked unverified', () {
      final records = SessionAnalytics.personalRecords([
        session(
          id: 'sloppy',
          startedAt: DateTime(2026, 5, 10),
          shots: makesAndMisses(18, 2),
          calibration: 0.4,
        ),
      ]);

      expect(
        records.firstWhere((r) => r.label == 'Best session accuracy').verified,
        isFalse,
      );
    });
  });

  group('trend explanations', () {
    test('one session explains nothing', () {
      expect(
        SessionAnalytics.explainTrends(
          [
            session(
              id: 'a',
              startedAt: DateTime(2026, 5, 1),
              shots: makesAndMisses(10, 10),
            ),
          ],
          now: DateTime(2026, 5, 20),
        ),
        isEmpty,
      );
    });

    test('too few attempts explains nothing', () {
      expect(
        SessionAnalytics.explainTrends(
          [
            session(
              id: 'b',
              startedAt: DateTime(2026, 5, 10),
              shots: makesAndMisses(2, 1),
            ),
            session(
              id: 'a',
              startedAt: DateTime(2026, 5, 1),
              shots: makesAndMisses(1, 2),
            ),
          ],
          now: DateTime(2026, 5, 20),
        ),
        isEmpty,
      );
    });

    test('a real improvement is reported with its direction', () {
      final explanations = SessionAnalytics.explainTrends(
        [
          session(
            id: 'recent',
            startedAt: DateTime(2026, 5, 15),
            shots: makesAndMisses(16, 4),
          ),
          session(
            id: 'older',
            startedAt: DateTime(2026, 5, 1),
            shots: makesAndMisses(8, 12),
          ),
        ],
        now: DateTime(2026, 5, 20),
      );

      final accuracy = explanations.firstWhere((e) => e.metric == 'Accuracy');
      expect(accuracy.change, closeTo(40, 1e-9));
      expect(accuracy.summary, contains('up'));
      expect(accuracy.sampleSize, 20);
    });

    test('a calibration change is attributed away from performance', () {
      final explanations = SessionAnalytics.explainTrends(
        [
          session(
            id: 'recent',
            startedAt: DateTime(2026, 5, 15),
            shots: makesAndMisses(16, 4),
            calibration: 0.95,
          ),
          session(
            id: 'older',
            startedAt: DateTime(2026, 5, 1),
            shots: makesAndMisses(8, 12),
            calibration: 0.55,
          ),
        ],
        now: DateTime(2026, 5, 20),
      );

      final accuracy = explanations.firstWhere((e) => e.metric == 'Accuracy');
      expect(accuracy.attributedToSetup, greaterThan(0));
      expect(
        accuracy.contributingFactors.any((f) => f.contains('Calibration')),
        isTrue,
      );
    });

    test('a steady setup attributes nothing to the camera', () {
      final explanations = SessionAnalytics.explainTrends(
        [
          session(
            id: 'recent',
            startedAt: DateTime(2026, 5, 15),
            shots: makesAndMisses(16, 4),
            calibration: 0.9,
          ),
          session(
            id: 'older',
            startedAt: DateTime(2026, 5, 1),
            shots: makesAndMisses(8, 12),
            calibration: 0.9,
          ),
        ],
        now: DateTime(2026, 5, 20),
      );

      expect(
        explanations.firstWhere((e) => e.metric == 'Accuracy')
            .attributedToSetup,
        0,
      );
    });
  });

  group('best streak', () {
    test('an empty history has no streak', () {
      expect(SessionAnalytics.bestStreak(const []), 0);
    });

    test('the longest run across sessions wins', () {
      final best = SessionAnalytics.bestStreak([
        session(
          id: 'a',
          startedAt: DateTime(2026, 5, 1),
          shots: makesAndMisses(3, 1),
        ),
        session(
          id: 'b',
          startedAt: DateTime(2026, 5, 2),
          shots: makesAndMisses(7, 1),
        ),
      ]);

      expect(best, 7);
    });
  });
}
