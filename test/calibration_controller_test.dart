import 'package:arcvanta/data/calibration/calibration_solver.dart';
import 'package:arcvanta/data/calibration/conic.dart';
import 'package:arcvanta/data/capture/calibration_source.dart';
import 'package:arcvanta/data/capture/simulated_capture_source.dart';
import 'package:arcvanta/data/capture/simulated_scene.dart';
import 'package:arcvanta/state/calibration.dart';
import 'package:arcvanta/state/capture_pipeline.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

/// The controller decides when a solve is worth trusting, which is the
/// difference between a measured session and a plausible one. These tests feed
/// it scenes it should accept, scenes it should refuse, and scenes that change
/// underneath it.
void main() {
  late ProviderContainer container;
  late ScriptedCaptureSource capture;

  setUp(() {
    capture = ScriptedCaptureSource();
    container = ProviderContainer(
      overrides: [captureSourceProvider.overrideWithValue(capture)],
    );
    // The controller disposes itself when nothing is watching, which is right
    // on a screen the athlete has left and wrong in a test that reads it
    // between pumps. A screen holds it open; here that is this listener.
    container.listen(
      calibrationProvider,
      (_, _) {},
      fireImmediately: true,
    );
  });

  tearDown(() {
    container.dispose();
    return capture.dispose();
  });

  CalibrationController controller() =>
      container.read(calibrationProvider.notifier);

  CalibrationState state() => container.read(calibrationProvider);

  /// Feeds observations one at a time, letting the stream drain between each.
  Future<void> feed(int count, {int from = 0, bool rimVisible = true}) async {
    for (var i = 0; i < count; i++) {
      capture.emitObservation(
        SimulatedScene.observation(frame: from + i, rimVisible: rimVisible),
      );
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('it starts idle and touches nothing', () {
    expect(state().stage, CalibrationStage.idle);
    expect(state().solution, isNull);
    expect(container.read(courtFrameProvider), isNull);
  });

  test('starting opens the preview and searches', () async {
    await controller().start();

    expect(capture.previewing, isTrue);
    expect(state().stage, CalibrationStage.searching);
  });

  test('frames without a ring keep it searching rather than failing', () async {
    await controller().start();
    await feed(5, rimVisible: false);

    // Pointing the phone at the floor while setting up is normal, not an
    // error, and the interface should not shout about it.
    expect(state().stage, CalibrationStage.searching);
    expect(state().framesSeen, 5);
    expect(state().framesWithRim, 0);
  });

  test('one good frame is not enough to call it solved', () async {
    await controller().start();
    await feed(1);

    expect(state().stage, CalibrationStage.settling);
    expect(state().isSolved, isFalse);
    // The partial solve is still exposed, so the overlay can draw the ring it
    // has found while the run builds.
    expect(state().solution?.isUsable, isTrue);
  });

  test('a run of consistent frames settles into a solve', () async {
    await controller().start();
    await feed(CalibrationController.requiredSolves);

    expect(state().stage, CalibrationStage.solved);
    expect(state().isSolved, isTrue);
    expect(state().settleProgress, 1.0);
    expect(state().frame, isNotNull);
  });

  test('settling closes the preview once it has what it needs', () async {
    await controller().start();
    await feed(CalibrationController.requiredSolves);
    await Future<void>.delayed(Duration.zero);

    // Holding the camera open after the answer is known costs battery and
    // heat, and the session is about to reopen it anyway.
    expect(capture.previewing, isFalse);
  });

  test('the solved frame is plausible for the simulated tripod', () async {
    await controller().start();
    await feed(CalibrationController.requiredSolves);

    final frame = state().frame!;
    // The scene puts the ring about 8.8 m from the lens.
    expect(frame.rimCentre.length, closeTo(8.8, 1.0));
    expect(state().overall, greaterThan(0.5));
  });

  test('the score is the solver\'s, not the controller\'s', () async {
    await controller().start();
    await feed(CalibrationController.requiredSolves);

    final solution = state().solution!;
    expect(solution.overall, state().overall);
    expect(
      solution.factors.map((factor) => factor.label),
      containsAll(<String>['Court plane', 'Rim reference', 'Framing']),
    );
  });

  test('nothing reaches the session until it is committed', () async {
    await controller().start();
    await feed(CalibrationController.requiredSolves);

    expect(state().isSolved, isTrue);
    // The athlete is allowed to look at a poor score and go fix the tripod.
    expect(container.read(courtFrameProvider), isNull);

    controller().commit();
    expect(container.read(courtFrameProvider), same(state().frame));
  });

  test('committing before a solve does nothing', () async {
    await controller().start();
    await feed(2);

    controller().commit();
    expect(container.read(courtFrameProvider), isNull);
  });

  test('a scene that will not solve is reported, not retried forever', () async {
    await controller().start();

    // A ring four pixels across carries no usable geometry, and telling the
    // athlete to move closer is more useful than searching indefinitely.
    capture.emitObservation(_tinyRim());
    await Future<void>.delayed(Duration.zero);

    expect(state().stage, CalibrationStage.blocked);
    expect(state().failure, CalibrationFailure.rimTooSmall);
  });

  test('a blocked scene recovers when the framing improves', () async {
    await controller().start();
    capture.emitObservation(_tinyRim());
    await Future<void>.delayed(Duration.zero);
    expect(state().stage, CalibrationStage.blocked);

    await feed(CalibrationController.requiredSolves);
    expect(state().stage, CalibrationStage.solved);
  });

  test('moving the camera mid-run restarts the run', () async {
    await controller().start();
    await feed(CalibrationController.requiredSolves - 4);
    expect(state().stage, CalibrationStage.settling);
    final before = state().settleProgress;

    // The phone was knocked to a different spot. Everything measured before
    // this described a different camera, so averaging the two would produce a
    // frame that matches neither.
    capture.emitObservation(_movedRim());
    await Future<void>.delayed(Duration.zero);

    expect(state().settleProgress, lessThan(before));
    expect(state().stage, CalibrationStage.settling);
  });

  test('recalibrating clears the previous run', () async {
    await controller().start();
    await feed(CalibrationController.requiredSolves);
    expect(state().isSolved, isTrue);

    await controller().start();
    expect(state().stage, CalibrationStage.searching);
    expect(state().solution, isNull);
    expect(state().framesSeen, 0);
  });

  test('cancelling stops the preview and resets', () async {
    await controller().start();
    await feed(3);

    await controller().cancel();
    expect(capture.previewing, isFalse);
    expect(state().stage, CalibrationStage.idle);
    expect(state().solution, isNull);
  });

  test('a steady tripod reports near-zero drift', () async {
    await controller().start();
    await feed(CalibrationController.requiredSolves);

    // The simulated wobble is sub-pixel, so the solved distance should barely
    // move across the run.
    expect(state().jitterPx, lessThan(2.0));
  });
}

/// The ring seen from far too far away to solve.
CalibrationObservation _tinyRim() {
  final base = SimulatedScene.observation(frame: 0);
  return CalibrationObservation(
    intrinsics: base.intrinsics,
    rim: RimObservation(
      ellipse: EllipseParams(
        centre: Vector2(960, 400),
        semiMajor: 4,
        semiMinor: 2,
        rotation: 0,
      ),
      source: RimObservationSource.detector,
      detectorConfidence: 0.6,
    ),
    backboard: base.backboard,
    conditions: base.conditions,
    gravity: base.gravity,
  );
}

/// The same ring after the tripod was knocked sideways.
CalibrationObservation _movedRim() {
  final base = SimulatedScene.observation(frame: 0);
  final original = base.rim!.ellipse;
  return CalibrationObservation(
    intrinsics: base.intrinsics,
    rim: RimObservation(
      // A noticeably rounder ellipse means a noticeably different viewing
      // angle, which is what being knocked over looks like to the solver.
      ellipse: EllipseParams(
        centre: original.centre,
        semiMajor: original.semiMajor * 2.4,
        semiMinor: original.semiMinor * 1.6,
        rotation: original.rotation,
      ),
      source: RimObservationSource.detector,
      detectorConfidence: 0.9,
    ),
    backboard: base.backboard,
    conditions: base.conditions,
    gravity: base.gravity,
  );
}
