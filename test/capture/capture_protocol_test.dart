import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:arcvanta/data/capture/capture_protocol.dart';
import 'package:arcvanta/data/capture/model_contract.dart';
import 'package:arcvanta/data/models/pose.dart';
import 'package:flutter_test/flutter_test.dart';

Float64List _keypoints({double x = 100, double y = 200, double score = 0.9}) {
  final values = Float64List(ModelContract.poseKeypointCount * 3);
  for (var i = 0; i < ModelContract.poseKeypointCount; i++) {
    values[i * 3] = x + i;
    values[i * 3 + 1] = y + i * 2;
    values[i * 3 + 2] = score;
  }
  return values;
}

Map<Object?, Object?> _frame({
  Object? people,
  Object? ball,
  Object? rimEllipse,
  Object? intrinsics,
  Object? gravity,
}) => <Object?, Object?>{
  'type': 'detections',
  'tMs': 1234,
  'people': people ??
      [
        {
          'box': Float64List.fromList([80.0, 120.0, 260.0, 700.0]),
          'score': 0.94,
          'keypoints': _keypoints(),
        },
      ],
  'ball': ball,
  'rim': null,
  'rimEllipse': rimEllipse,
  'backboard': null,
  'intrinsics': intrinsics ??
      {
        'fx': 1440.0,
        'fy': 1440.0,
        'cx': 960.0,
        'cy': 540.0,
        'width': 1920,
        'height': 1080,
        'fromDevice': true,
      },
  'gravity': gravity,
  'conditions': {
    'meanLuma': 0.5,
    'clipped': 0.03,
    'motion': 0.4,
    'frameRate': 60,
    'tripod': true,
  },
  'fps': 42,
  'thermalHeadroom': 0.87,
  'backend': 'NNAPI',
};

void main() {
  group('decoding a detection frame', () {
    test('reads the scalars', () {
      final frame = CaptureProtocol.decodeDetectionFrame(_frame());

      expect(frame.timestampMs, 1234);
      expect(frame.processedFps, 42);
      expect(frame.thermalHeadroom, closeTo(0.87, 1e-12));
      expect(frame.backend, InferenceBackend.nnapi);
    });

    test('reads the intrinsics', () {
      final frame = CaptureProtocol.decodeDetectionFrame(_frame());

      expect(frame.intrinsics.focalXPx, 1440);
      expect(frame.intrinsics.widthPx, 1920);
      expect(frame.intrinsics.fromDevice, isTrue);
    });

    test('reads a person with all seventeen landmarks', () {
      final frame = CaptureProtocol.decodeDetectionFrame(_frame());

      expect(frame.people, hasLength(1));
      final person = frame.people.single;
      expect(person.keypoints, hasLength(17));
      expect(person.keypointScores, hasLength(17));
      expect(person.keypoints.first.x, 100);
      expect(person.meanScore, closeTo(0.9, 1e-12));
      expect(person.box.type, DetectionClass.person);
    });

    test('picks the largest person as the subject', () {
      final frame = CaptureProtocol.decodeDetectionFrame(
        _frame(
          people: [
            {
              'box': Float64List.fromList([0.0, 0.0, 40.0, 90.0]),
              'score': 0.8,
              'keypoints': _keypoints(),
            },
            {
              'box': Float64List.fromList([100.0, 100.0, 400.0, 800.0]),
              'score': 0.9,
              'keypoints': _keypoints(x: 300),
            },
          ],
        ),
      );

      expect(frame.subject!.box.width, 300);
    });

    test('an absent ball stays absent', () {
      expect(CaptureProtocol.decodeDetectionFrame(_frame()).ball, isNull);
    });

    test('reads a ball and its equivalent radius', () {
      final frame = CaptureProtocol.decodeDetectionFrame(
        _frame(
          ball: {
            'box': Float64List.fromList([100.0, 100.0, 140.0, 140.0]),
            'score': 0.88,
          },
        ),
      );

      expect(frame.ball!.centre.x, 120);
      expect(frame.ball!.equivalentRadius, 20);
      expect(frame.ball!.type, DetectionClass.ball);
    });

    test('gravity of zero length means no reading, not free fall', () {
      final frame = CaptureProtocol.decodeDetectionFrame(
        _frame(gravity: Float64List.fromList([0.0, 0.0, 0.0])),
      );
      expect(frame.gravity, isNull);
    });

    test('reads a gravity vector', () {
      final frame = CaptureProtocol.decodeDetectionFrame(
        _frame(gravity: Float64List.fromList([0.1, 9.8, -0.2])),
      );
      expect(frame.gravity!.y, closeTo(9.8, 1e-12));
    });

    test('accepts plain number lists as well as typed ones', () {
      final frame = CaptureProtocol.decodeDetectionFrame(
        _frame(ball: {'box': <double>[10, 10, 30, 30], 'score': 0.5}),
      );
      expect(frame.ball!.centre.x, 20);
    });
  });

  group('the rim ellipse', () {
    test('is read as given when the axes are in order', () {
      final frame = CaptureProtocol.decodeDetectionFrame(
        _frame(
          rimEllipse: Float64List.fromList([960.0, 300.0, 80.0, 26.0, 0.2]),
        ),
      );

      final ellipse = frame.rimEllipse!;
      expect(ellipse.centre.x, 960);
      expect(ellipse.semiMajor, 80);
      expect(ellipse.semiMinor, 26);
      expect(ellipse.rotation, closeTo(0.2, 1e-12));
    });

    test('swapped axes are corrected rather than trusted', () {
      // A bridge that reported width then height would otherwise flip the
      // solved rim tilt by ninety degrees.
      final frame = CaptureProtocol.decodeDetectionFrame(
        _frame(
          rimEllipse: Float64List.fromList([960.0, 300.0, 26.0, 80.0, 0.0]),
        ),
      );

      final ellipse = frame.rimEllipse!;
      expect(ellipse.semiMajor, 80);
      expect(ellipse.semiMinor, 26);
      expect(ellipse.rotation, closeTo(1.5707963, 1e-6));
    });

    test('feeds the calibration parts when present', () {
      final frame = CaptureProtocol.decodeDetectionFrame(
        _frame(
          rimEllipse: Float64List.fromList([960.0, 300.0, 80.0, 26.0, 0.0]),
        ),
      );
      expect(frame.calibrationParts.rim, isNotNull);
    });

    test('leaves the calibration without a rim when absent', () {
      expect(
        CaptureProtocol.decodeDetectionFrame(_frame()).calibrationParts.rim,
        isNull,
      );
    });
  });

  group('refuses to guess at a frame it cannot read', () {
    void expectRejects(Map<Object?, Object?> payload, Matcher message) {
      expect(
        () => CaptureProtocol.decodeDetectionFrame(payload),
        throwsA(
          isA<CaptureProtocolException>().having(
            (e) => e.message,
            'message',
            message,
          ),
        ),
      );
    }

    test('the wrong event type', () {
      expectRejects({'type': 'something-else'}, contains('detections'));
    });

    test('the wrong number of keypoints', () {
      expectRejects(
        _frame(
          people: [
            {
              'box': Float64List.fromList([0.0, 0.0, 10.0, 10.0]),
              'score': 0.9,
              'keypoints': Float64List(30),
            },
          ],
        ),
        contains('keypoint'),
      );
    });

    test('a box with the wrong arity', () {
      expectRejects(
        _frame(ball: {'box': Float64List.fromList([1.0, 2.0]), 'score': 1.0}),
        contains('4 values'),
      );
    });

    test('an ellipse with the wrong arity', () {
      expectRejects(
        _frame(rimEllipse: Float64List.fromList([1.0, 2.0, 3.0])),
        contains('5 values'),
      );
    });

    test('missing intrinsics', () {
      final payload = _frame()..['intrinsics'] = null;
      expectRejects(payload, contains('intrinsics'));
    });

    test('a non-numeric value where a number belongs', () {
      expectRejects(
        _frame(ball: {'box': <Object>['a', 'b', 'c', 'd'], 'score': 1.0}),
        contains('non-number'),
      );
    });
  });

  group('runtime info', () {
    test('is decoded and signed', () {
      final info = CaptureProtocol.decodeRuntimeInfo({
        'contractVersion': ModelContract.version,
        'detectorVersion': 'rtmdet-m-1.0.0',
        'poseVersion': 'rtmpose-m-1.0.0',
        'backend': 'CoreML',
      });

      expect(info.isCompatible, isTrue);
      expect(info.backend, InferenceBackend.coreml);
      expect(info.signature, 'rtmdet-m-1.0.0 / rtmpose-m-1.0.0 / CoreML');
    });

    test('a mismatched contract is not compatible', () {
      final info = CaptureProtocol.decodeRuntimeInfo({
        'contractVersion': ModelContract.version + 1,
        'detectorVersion': 'x',
        'poseVersion': 'y',
        'backend': 'CPU',
      });
      expect(info.isCompatible, isFalse);
    });

    test('an unknown backend does not throw', () {
      expect(InferenceBackend.fromWire('something'), InferenceBackend.unknown);
      expect(InferenceBackend.fromWire(null), InferenceBackend.unknown);
    });
  });

  group('the Dart mirror matches the checked-in contract', () {
    late Map<String, dynamic> contract;

    setUpAll(() {
      contract =
          jsonDecode(
                File('vision/contract/model_contract.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
    });

    test('contract version', () {
      expect(contract['contractVersion'], ModelContract.version);
    });

    test('detector input and file name', () {
      final detector = contract['detector'] as Map<String, dynamic>;
      final shape = (detector['input'] as Map)['shape'] as List;
      expect(detector['file'], ModelContract.detectorFile);
      expect(shape[2], ModelContract.detectorInputHeight);
      expect(shape[3], ModelContract.detectorInputWidth);
    });

    test('detector classes line up with the enum', () {
      final classes = (contract['detector'] as Map)['classes'] as List;
      expect(classes, hasLength(DetectionClass.values.length));
      for (final entry in classes.cast<Map<String, dynamic>>()) {
        final matched = DetectionClass.fromId(entry['id'] as int);
        expect(matched, isNotNull, reason: 'no enum for id ${entry['id']}');
        expect(matched!.wireName, entry['name']);
      }
    });

    test('pose input, split ratio and keypoint order', () {
      final pose = contract['pose'] as Map<String, dynamic>;
      final shape = (pose['input'] as Map)['shape'] as List;
      expect(pose['file'], ModelContract.poseFile);
      expect(shape[2], ModelContract.poseInputHeight);
      expect(shape[3], ModelContract.poseInputWidth);
      expect(
        (pose['decode'] as Map)['splitRatio'],
        ModelContract.simccSplitRatio,
      );
      expect(pose['keypoints'], ModelContract.cocoKeypoints);
    });

    test('simcc output widths follow from the input and the split ratio', () {
      final outputs = ((contract['pose'] as Map)['outputs'] as List)
          .cast<Map<String, dynamic>>();
      final x = outputs.firstWhere((o) => o['name'] == 'simcc_x');
      final y = outputs.firstWhere((o) => o['name'] == 'simcc_y');

      expect(
        (x['shape'] as List)[2],
        ModelContract.poseInputWidth * ModelContract.simccSplitRatio,
      );
      expect(
        (y['shape'] as List)[2],
        ModelContract.poseInputHeight * ModelContract.simccSplitRatio,
      );
      expect((x['shape'] as List)[1], ModelContract.poseKeypointCount);
    });

    test('every joint maps to a keypoint the contract declares', () {
      final mapping = contract['jointMapping'] as Map<String, dynamic>;

      for (final joint in PoseJoint.values) {
        final entry = mapping[joint.name];
        expect(entry, isNotNull, reason: '${joint.name} is not mapped');

        final index = ModelContract.cocoIndexForJoint[joint];
        final derived = ModelContract.derivedJoints[joint];
        expect(
          index != null || derived != null,
          isTrue,
          reason: '${joint.name} is neither read nor derived',
        );

        if (index != null) {
          expect((entry as Map)['from'], ModelContract.cocoKeypoints[index]);
        } else {
          final pair = (entry as Map)['midpoint'] as List;
          expect(pair, hasLength(2));
          expect(
            pair[0],
            ModelContract.cocoKeypoints[
                ModelContract.cocoIndexForJoint[derived!.$1]!],
          );
        }
      }
    });

    test('the mirror covers every joint the product draws', () {
      expect(
        ModelContract.cocoIndexForJoint.length +
            ModelContract.derivedJoints.length,
        PoseJoint.values.length,
      );
    });
  });
}
