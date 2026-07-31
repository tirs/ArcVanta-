import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../calibration/calibration_solver.dart';
import '../calibration/camera_intrinsics.dart';
import '../calibration/conic.dart';
import 'model_contract.dart';

/// Thrown when the native side sends something this build cannot read.
///
/// Preferred to a silent default: a frame decoded wrongly would become a
/// measurement reported in centimetres, and a wrong number is worse than a
/// missing one.
class CaptureProtocolException implements Exception {
  const CaptureProtocolException(this.message);

  final String message;

  @override
  String toString() => 'CaptureProtocolException: $message';
}

/// One detected box.
class Detection {
  const Detection({
    required this.type,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.score,
  });

  final DetectionClass type;

  /// Pixels in the analysis frame, which is the space the intrinsics describe.
  final double left;
  final double top;
  final double right;
  final double bottom;

  final double score;

  double get width => right - left;
  double get height => bottom - top;
  Vector2 get centre => Vector2((left + right) / 2, (top + bottom) / 2);

  /// Radius of the circle with the same area as the box. Used to estimate ball
  /// depth, which is the one measurement that does not need the shot plane.
  double get equivalentRadius => (width + height) / 4;
}

/// A person detection with their landmarks attached.
class PersonDetection {
  const PersonDetection({
    required this.box,
    required this.keypoints,
    required this.keypointScores,
  });

  final Detection box;

  /// COCO-17 landmarks in analysis-frame pixels, in the order given by
  /// [ModelContract.cocoKeypoints].
  final List<Vector2> keypoints;
  final List<double> keypointScores;

  /// Mean landmark score, which is what the product reports as tracking
  /// confidence for this person.
  double get meanScore {
    if (keypointScores.isEmpty) return 0;
    var sum = 0.0;
    for (final score in keypointScores) {
      sum += score;
    }
    return sum / keypointScores.length;
  }
}

/// Everything the native pipeline saw in one frame.
///
/// Deliberately raw. No phase, no shot result, no metric: those are decided in
/// Dart, where they can be tested without a camera and where there is one
/// implementation rather than one per platform.
class DetectionFrame {
  const DetectionFrame({
    required this.timestampMs,
    required this.people,
    required this.ball,
    required this.rim,
    required this.rimEllipse,
    required this.backboard,
    required this.intrinsics,
    required this.gravity,
    required this.conditions,
    required this.processedFps,
    required this.thermalHeadroom,
    required this.backend,
  });

  final int timestampMs;
  final List<PersonDetection> people;
  final Detection? ball;
  final Detection? rim;

  /// The ring's outline when the detector produced a mask good enough to fit
  /// one. Far more useful than the box, because the pose solve needs the
  /// ellipse and a box only bounds it.
  final EllipseParams? rimEllipse;

  final Detection? backboard;
  final CameraIntrinsics intrinsics;
  final Vector3? gravity;
  final CaptureConditions conditions;
  final int processedFps;
  final double thermalHeadroom;
  final InferenceBackend backend;

  /// The person the session is about: the largest box, since the shooter is
  /// the subject and stands nearest the camera's subject area.
  PersonDetection? get subject {
    PersonDetection? best;
    var bestArea = 0.0;
    for (final person in people) {
      final area = person.box.width * person.box.height;
      if (area > bestArea) {
        bestArea = area;
        best = person;
      }
    }
    return best;
  }

  /// The calibration view of this frame.
  CalibrationObservationParts get calibrationParts =>
      CalibrationObservationParts(
        intrinsics: intrinsics,
        rim: rimEllipse == null
            ? null
            : RimObservation(
                ellipse: rimEllipse!,
                source: RimObservationSource.detector,
                detectorConfidence: rim?.score ?? 0.5,
              ),
        backboard: backboard == null
            ? null
            : BackboardObservation(
                centre: backboard!.centre,
                widthPx: backboard!.width,
                heightPx: backboard!.height,
                detectorConfidence: backboard!.score,
              ),
        conditions: conditions,
        gravity: gravity,
      );
}

/// The subset of a [DetectionFrame] the calibration solver consumes.
class CalibrationObservationParts {
  const CalibrationObservationParts({
    required this.intrinsics,
    required this.rim,
    required this.backboard,
    required this.conditions,
    required this.gravity,
  });

  final CameraIntrinsics intrinsics;
  final RimObservation? rim;
  final BackboardObservation? backboard;
  final CaptureConditions conditions;
  final Vector3? gravity;
}

/// Decodes what the platform channel delivers.
///
/// The native side speaks the standard message codec, so everything arrives as
/// maps and typed lists. Landmarks travel as one flat [Float64List] rather
/// than a list of maps because this runs at frame rate and boxing 51 doubles
/// per person per frame is not free.
abstract final class CaptureProtocol {
  static const String methodChannel = 'ai.arcvanta/capture';
  static const String eventChannel = 'ai.arcvanta/capture/events';

  static const String eventDetections = 'detections';
  static const String eventError = 'error';

  static DetectionFrame decodeDetectionFrame(Map<Object?, Object?> payload) {
    final type = payload['type'];
    if (type != eventDetections) {
      throw CaptureProtocolException('expected a detections event, got $type');
    }

    final intrinsics = _decodeIntrinsics(payload['intrinsics']);

    return DetectionFrame(
      timestampMs: _int(payload['tMs'], 'tMs'),
      people: _decodePeople(payload['people']),
      ball: _decodeDetection(payload['ball'], DetectionClass.ball),
      rim: _decodeDetection(payload['rim'], DetectionClass.rim),
      rimEllipse: _decodeEllipse(payload['rimEllipse']),
      backboard: _decodeDetection(
        payload['backboard'],
        DetectionClass.backboard,
      ),
      intrinsics: intrinsics,
      gravity: _decodeVector3(payload['gravity']),
      conditions: _decodeConditions(payload['conditions']),
      processedFps: _int(payload['fps'] ?? 0, 'fps'),
      thermalHeadroom: _double(payload['thermalHeadroom'] ?? 1.0, 'thermal'),
      backend: InferenceBackend.fromWire(payload['backend'] as String?),
    );
  }

  static ModelRuntimeInfo decodeRuntimeInfo(Map<Object?, Object?> payload) {
    return ModelRuntimeInfo(
      contractVersion: _int(payload['contractVersion'], 'contractVersion'),
      detectorVersion: (payload['detectorVersion'] as String?) ?? 'unknown',
      poseVersion: (payload['poseVersion'] as String?) ?? 'unknown',
      backend: InferenceBackend.fromWire(payload['backend'] as String?),
    );
  }

  static List<PersonDetection> _decodePeople(Object? raw) {
    if (raw == null) return const [];
    if (raw is! List) {
      throw const CaptureProtocolException('people should be a list');
    }

    return [
      for (final entry in raw)
        () {
          if (entry is! Map) {
            throw const CaptureProtocolException('person should be a map');
          }
          // The person map carries box and score at the top level, the same
          // shape as every other detection.
          final box = _decodeDetection(entry, DetectionClass.person);
          if (box == null) {
            throw const CaptureProtocolException('person is missing its box');
          }

          final flat = _floats(entry['keypoints'], 'keypoints');
          final expected = ModelContract.poseKeypointCount * 3;
          if (flat.length != expected) {
            throw CaptureProtocolException(
              'expected $expected keypoint values, got ${flat.length}',
            );
          }

          final points = <Vector2>[];
          final scores = <double>[];
          for (var i = 0; i < ModelContract.poseKeypointCount; i++) {
            points.add(Vector2(flat[i * 3], flat[i * 3 + 1]));
            scores.add(flat[i * 3 + 2]);
          }

          return PersonDetection(
            box: box,
            keypoints: points,
            keypointScores: scores,
          );
        }(),
    ];
  }

  static Detection? _decodeDetection(Object? raw, DetectionClass type) {
    if (raw == null) return null;
    if (raw is! Map) {
      throw CaptureProtocolException('${type.wireName} should be a map');
    }

    final box = _floats(raw['box'], '${type.wireName} box');
    if (box.length != 4) {
      throw CaptureProtocolException(
        '${type.wireName} box needs 4 values, got ${box.length}',
      );
    }

    return Detection(
      type: type,
      left: box[0],
      top: box[1],
      right: box[2],
      bottom: box[3],
      score: _double(raw['score'] ?? 1.0, 'score'),
    );
  }

  static EllipseParams? _decodeEllipse(Object? raw) {
    if (raw == null) return null;
    final values = _floats(raw, 'rimEllipse');
    if (values.length != 5) {
      throw CaptureProtocolException(
        'rimEllipse needs 5 values, got ${values.length}',
      );
    }

    // Guard the ordering rather than trusting it: a swapped pair would flip
    // the solved rim tilt by ninety degrees.
    final major = values[2] >= values[3] ? values[2] : values[3];
    final minor = values[2] >= values[3] ? values[3] : values[2];
    final rotation = values[2] >= values[3] ? values[4] : values[4] + 1.5707963;

    return EllipseParams(
      centre: Vector2(values[0], values[1]),
      semiMajor: major,
      semiMinor: minor,
      rotation: rotation,
    );
  }

  static CameraIntrinsics _decodeIntrinsics(Object? raw) {
    if (raw is! Map) {
      throw const CaptureProtocolException('intrinsics are missing');
    }

    return CameraIntrinsics(
      focalXPx: _double(raw['fx'], 'fx'),
      focalYPx: _double(raw['fy'], 'fy'),
      principalXPx: _double(raw['cx'], 'cx'),
      principalYPx: _double(raw['cy'], 'cy'),
      widthPx: _int(raw['width'], 'width'),
      heightPx: _int(raw['height'], 'height'),
      fromDevice: raw['fromDevice'] as bool? ?? false,
    );
  }

  static Vector3? _decodeVector3(Object? raw) {
    if (raw == null) return null;
    final values = _floats(raw, 'gravity');
    if (values.length != 3) {
      throw CaptureProtocolException(
        'gravity needs 3 values, got ${values.length}',
      );
    }
    final vector = Vector3(values[0], values[1], values[2]);
    // A zero reading is the sensor saying nothing, not the phone in free fall.
    return vector.length < 1e-6 ? null : vector;
  }

  static CaptureConditions _decodeConditions(Object? raw) {
    if (raw is! Map) return const CaptureConditions();
    return CaptureConditions(
      meanLuma: _double(raw['meanLuma'] ?? 0.55, 'meanLuma'),
      lumaClippedFraction: _double(raw['clipped'] ?? 0.02, 'clipped'),
      motionPixelsPerFrame: _double(raw['motion'] ?? 0.4, 'motion'),
      frameRate: _int(raw['frameRate'] ?? 60, 'frameRate'),
      hasTripod: raw['tripod'] as bool? ?? true,
    );
  }

  static List<double> _floats(Object? raw, String field) {
    if (raw is Float64List) return raw;
    if (raw is Float32List) return raw.map((v) => v.toDouble()).toList();
    if (raw is List) {
      return [
        for (final value in raw)
          if (value is num)
            value.toDouble()
          else
            throw CaptureProtocolException('$field holds a non-number'),
      ];
    }
    throw CaptureProtocolException('$field should be a list of numbers');
  }

  static double _double(Object? raw, String field) {
    if (raw is num) return raw.toDouble();
    throw CaptureProtocolException('$field should be a number, got $raw');
  }

  static int _int(Object? raw, String field) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    throw CaptureProtocolException('$field should be an integer, got $raw');
  }
}
