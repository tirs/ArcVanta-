import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../data/models/session.dart';
import 'app_settings.dart';

/// Speaks and buzzes the coaching cues.
///
/// A shooter is looking at the rim, not the phone, so a cue that only exists
/// on screen is a cue nobody receives. Speech is the delivery path that
/// matches how the app is actually used, and the haptic is what makes a
/// spoken cue land when the gym is loud.
///
/// Only the headline is spoken. The detail line is written to be read, and
/// reading it aloud takes longer than the gap between two shots.
class CoachingVoice {
  CoachingVoice(this._ref);

  final Ref _ref;

  final FlutterTts _tts = FlutterTts();
  bool _configured = false;
  String? _lastSpokenCueId;

  Future<void> announce(CoachingCue cue) async {
    final settings = _ref.read(appSettingsProvider);
    if (settings.feedbackFrequency == FeedbackFrequency.off) return;

    // Cues are re-emitted while they stay relevant, and hearing the same
    // sentence four times is how an athlete learns to ignore the voice.
    if (cue.id == _lastSpokenCueId) return;
    _lastSpokenCueId = cue.id;

    if (settings.hapticFeedback) {
      unawaited(HapticFeedback.mediumImpact());
    }
    if (settings.spokenFeedback) {
      unawaited(_speak(cue.headline));
    }
  }

  /// Marks a made shot without saying anything, for athletes who want to know
  /// a shot registered without being talked at.
  Future<void> confirmMake() async {
    if (!_ref.read(appSettingsProvider).hapticFeedback) return;
    return HapticFeedback.selectionClick();
  }

  void reset() => _lastSpokenCueId = null;

  Future<void> _speak(String text) async {
    try {
      await _configure();
      await _tts.stop();
      await _tts.speak(text);
    } catch (error) {
      // Speech is an enhancement. A device with no voice installed should
      // lose the audio, not the session.
      debugPrint('Coaching voice unavailable: $error');
    }
  }

  Future<void> _configure() async {
    if (_configured) return;
    _configured = true;
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1);
    await _tts.setPitch(1);
    // Ducks music instead of stopping it: people shoot to their own playlist.
    await _tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        IosTextToSpeechAudioCategoryOptions.duckOthers,
      ],
    );
  }

  Future<void> dispose() => _tts.stop();
}

final coachingVoiceProvider = Provider<CoachingVoice>((ref) {
  final voice = CoachingVoice(ref);
  ref.onDispose(voice.dispose);
  return voice;
});
