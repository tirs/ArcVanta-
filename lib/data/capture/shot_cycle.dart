import '../models/pose.dart';

/// Timings of one simulated shot cycle in milliseconds.
///
/// The simulated pipeline derives the skeleton, ball position and phase label
/// from this single clock so the overlay stays synchronised with the event
/// stream. A real pipeline reports phase from the motion itself and does not
/// use this class.
abstract final class ShotCycle {
  static const int approach = 900;
  static const int ready = 620;
  static const int dip = 300;
  static const int load = 260;
  static const int upward = 220;
  static const int setPoint = 180;
  static const int release = 90;
  static const int flight = 900;
  static const int rim = 260;
  static const int landing = 380;
  static const int recovery = 1100;

  static const int total =
      approach +
      ready +
      dip +
      load +
      upward +
      setPoint +
      release +
      flight +
      rim +
      landing +
      recovery;

  /// Point in the cycle at which the result becomes known.
  static const int resultAt =
      approach + ready + dip + load + upward + setPoint + release + flight;

  static ShotPhaseKind phaseAt(int ms) {
    var cursor = 0;
    if (ms < (cursor += approach)) return ShotPhaseKind.possession;
    if (ms < (cursor += ready)) return ShotPhaseKind.ready;
    if (ms < (cursor += dip)) return ShotPhaseKind.dip;
    if (ms < (cursor += load)) return ShotPhaseKind.load;
    if (ms < (cursor += upward)) return ShotPhaseKind.upward;
    if (ms < (cursor += setPoint)) return ShotPhaseKind.setPoint;
    if (ms < (cursor += release)) return ShotPhaseKind.release;
    if (ms < (cursor += flight)) return ShotPhaseKind.flight;
    if (ms < (cursor += rim)) return ShotPhaseKind.rimInteraction;
    if (ms < (cursor += landing)) return ShotPhaseKind.landing;
    return ShotPhaseKind.recovery;
  }

  /// Progress inside the flight phase, or null when the ball is in hand.
  static double? flightProgress(int ms) {
    const start = approach + ready + dip + load + upward + setPoint + release;
    const end = start + flight + rim;
    if (ms < start || ms > end) return null;
    return ((ms - start) / (flight + rim)).clamp(0.0, 1.0);
  }
}
