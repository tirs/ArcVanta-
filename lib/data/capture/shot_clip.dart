import 'dart:ui' show Offset, Rect;

import '../models/pose.dart';

/// One frame of capture data saved during a shot for replay.
///
/// All coordinates are in normalised image space (0–1).
class ClipFrame {
  const ClipFrame({
    required this.timestampMs,
    required this.pose,
    required this.ball,
    required this.rim,
    required this.trackingConfidence,
  });

  final int timestampMs;
  final PoseFrame? pose;
  final Offset? ball;
  final Rect? rim;
  final double? trackingConfidence;
}

/// A recorded shot clip: the frames leading up to and after a shot event.
class ShotClip {
  const ShotClip({
    required this.shotIndex,
    required this.frames,
    required this.releaseFrameIndex,
    required this.made,
  });

  final int shotIndex;
  final List<ClipFrame> frames;

  /// Which frame in [frames] is closest to the release point.
  final int releaseFrameIndex;
  final bool? made;

  Duration get duration {
    if (frames.length < 2) return Duration.zero;
    return Duration(
      milliseconds: frames.last.timestampMs - frames.first.timestampMs,
    );
  }
}

/// Buffers capture frames in a ring and produces [ShotClip]s around shots.
class ClipRecorder {
  ClipRecorder({this.preRollFrames = 30, this.postRollFrames = 60});

  final int preRollFrames;
  final int postRollFrames;

  final List<ClipFrame> _ring = [];
  int _ringHead = 0;

  bool _recording = false;
  int _postRollRemaining = 0;
  int _shotIndex = 0;
  int _releaseFrame = 0;
  bool? _made;
  final List<ClipFrame> _clip = [];

  /// Call every frame with the current detection data.
  void pushFrame(ClipFrame frame) {
    if (_recording) {
      _clip.add(frame);
      _postRollRemaining--;
      if (_postRollRemaining <= 0) {
        _recording = false;
      }
    } else {
      if (_ring.length < preRollFrames) {
        _ring.add(frame);
      } else {
        _ring[_ringHead] = frame;
        _ringHead = (_ringHead + 1) % preRollFrames;
      }
    }
  }

  /// Call when a shot release is detected. Starts capturing post-roll.
  void onShotDetected({required int shotIndex, required bool? made}) {
    _shotIndex = shotIndex;
    _made = made;
    _recording = true;
    _postRollRemaining = postRollFrames;

    _clip.clear();
    // Drain ring buffer in order (oldest first).
    if (_ring.length == preRollFrames) {
      for (var i = 0; i < preRollFrames; i++) {
        _clip.add(_ring[(_ringHead + i) % preRollFrames]);
      }
    } else {
      _clip.addAll(_ring);
    }
    _releaseFrame = _clip.length;
    _ring.clear();
    _ringHead = 0;
  }

  /// Returns the completed clip, or null if still recording.
  ShotClip? takeClip() {
    if (_recording || _clip.isEmpty) return null;
    final clip = ShotClip(
      shotIndex: _shotIndex,
      frames: List.unmodifiable(_clip),
      releaseFrameIndex: _releaseFrame,
      made: _made,
    );
    _clip.clear();
    return clip;
  }

  void reset() {
    _ring.clear();
    _ringHead = 0;
    _recording = false;
    _clip.clear();
  }
}
