/// A single day on a progress trend.
class ProgressPoint {
  const ProgressPoint({
    required this.date,
    required this.attempts,
    required this.makes,
    required this.mechanicsScore,
    required this.consistencyScore,
    required this.averageEntryAngle,
    required this.calibrationQuality,
  });

  final DateTime date;
  final int attempts;
  final int makes;
  final double mechanicsScore;
  final double consistencyScore;
  final double averageEntryAngle;
  final double calibrationQuality;

  double get percentage => attempts == 0 ? 0 : makes / attempts * 100;
  bool get trained => attempts > 0;
}

enum TrendRange {
  week,
  month,
  quarter,
  season;

  String get label => switch (this) {
        TrendRange.week => '7 days',
        TrendRange.month => '30 days',
        TrendRange.quarter => '90 days',
        TrendRange.season => 'Season',
      };

  int get days => switch (this) {
        TrendRange.week => 7,
        TrendRange.month => 30,
        TrendRange.quarter => 90,
        TrendRange.season => 180,
      };
}

/// A personal record with the evidence that produced it.
class PersonalRecord {
  const PersonalRecord({
    required this.label,
    required this.value,
    required this.unit,
    required this.achievedAt,
    required this.context,
    required this.verified,
  });

  final String label;
  final String value;
  final String unit;
  final DateTime achievedAt;
  final String context;
  final bool verified;
}

/// An explanation of why a headline number moved, separating real change from
/// sampling and camera-setup effects.
class TrendExplanation {
  const TrendExplanation({
    required this.metric,
    required this.change,
    required this.summary,
    required this.contributingFactors,
    required this.sampleSize,
    required this.attributedToSetup,
  });

  final String metric;
  final double change;
  final String summary;
  final List<String> contributingFactors;
  final int sampleSize;

  /// Portion of the movement the system attributes to camera placement or
  /// calibration change rather than performance.
  final double attributedToSetup;
}
