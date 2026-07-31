import '../../state/app_settings.dart';
import '../models/confidence.dart';
import '../models/profile.dart';
import 'codecs.dart';

/// Reads and writes [AppSettings].
///
/// Kept apart from the domain codecs because settings are the one record where
/// a missing field is normal rather than suspicious: every release adds
/// options, and an older stored blob has to keep working. Each field falls back
/// to the constructor default individually.
abstract final class SettingsCodec {
  static Map<String, Object?> toJson(AppSettings settings) => {
    'onboardingComplete': settings.onboardingComplete,
    'role': settings.role.name,
    'guestMode': settings.guestMode,
    'preferredAngle': settings.preferredAngle.name,
    'spokenFeedback': settings.spokenFeedback,
    'hapticFeedback': settings.hapticFeedback,
    'feedbackFrequency': settings.feedbackFrequency.name,
    'showOverlays': settings.showOverlays,
    'showSkeleton': settings.showSkeleton,
    'showTrajectory': settings.showTrajectory,
    'showZones': settings.showZones,
    'highContrast': settings.highContrast,
    'reducedMotion': settings.reducedMotion,
    'largeText': settings.largeText,
    'leftHandedLayout': settings.leftHandedLayout,
    'captionsForAudioCoaching': settings.captionsForAudioCoaching,
    'localProcessingOnly': settings.localProcessingOnly,
    'cloudBackup': settings.cloudBackup,
    'modelTrainingConsent': settings.modelTrainingConsent,
    'retention': settings.retention.name,
    'quietHoursEnabled': settings.quietHoursEnabled,
    'quietHoursStartHour': settings.quietHoursStartHour,
    'quietHoursEndHour': settings.quietHoursEndHour,
    'notificationOptIns': settings.notificationOptIns,
    'highFrameRateCapture': settings.highFrameRateCapture,
    'thermalGuard': settings.thermalGuard,
    'storageBudgetGb': settings.storageBudgetGb,
    'demoDataEnabled': settings.demoDataEnabled,
    'courtName': settings.courtName,
  };

  static AppSettings fromJson(Map<String, Object?> json) {
    const defaults = AppSettings();

    bool flag(String key, bool fallback) =>
        json.containsKey(key) ? Codecs.boolean(json[key], fallback) : fallback;

    final optIns = <String, bool>{...defaults.notificationOptIns};
    final storedOptIns = json['notificationOptIns'];
    if (storedOptIns is Map) {
      for (final entry in storedOptIns.entries) {
        optIns['${entry.key}'] = Codecs.boolean(entry.value, true);
      }
    }

    return AppSettings(
      onboardingComplete: flag('onboardingComplete', false),
      role: Codecs.enumByName(
        AccountRole.values,
        json['role'],
        defaults.role,
      ),
      guestMode: flag('guestMode', defaults.guestMode),
      preferredAngle: Codecs.enumByName(
        CameraAngle.values,
        json['preferredAngle'],
        defaults.preferredAngle,
      ),
      spokenFeedback: flag('spokenFeedback', defaults.spokenFeedback),
      hapticFeedback: flag('hapticFeedback', defaults.hapticFeedback),
      feedbackFrequency: Codecs.enumByName(
        FeedbackFrequency.values,
        json['feedbackFrequency'],
        defaults.feedbackFrequency,
      ),
      showOverlays: flag('showOverlays', defaults.showOverlays),
      showSkeleton: flag('showSkeleton', defaults.showSkeleton),
      showTrajectory: flag('showTrajectory', defaults.showTrajectory),
      showZones: flag('showZones', defaults.showZones),
      highContrast: flag('highContrast', defaults.highContrast),
      reducedMotion: flag('reducedMotion', defaults.reducedMotion),
      largeText: flag('largeText', defaults.largeText),
      leftHandedLayout: flag('leftHandedLayout', defaults.leftHandedLayout),
      captionsForAudioCoaching: flag(
        'captionsForAudioCoaching',
        defaults.captionsForAudioCoaching,
      ),
      localProcessingOnly: flag(
        'localProcessingOnly',
        defaults.localProcessingOnly,
      ),
      cloudBackup: flag('cloudBackup', defaults.cloudBackup),
      modelTrainingConsent: flag(
        'modelTrainingConsent',
        defaults.modelTrainingConsent,
      ),
      retention: Codecs.enumByName(
        RetentionWindow.values,
        json['retention'],
        defaults.retention,
      ),
      quietHoursEnabled: flag('quietHoursEnabled', defaults.quietHoursEnabled),
      quietHoursStartHour: Codecs.integer(
        json['quietHoursStartHour'],
        defaults.quietHoursStartHour,
      ),
      quietHoursEndHour: Codecs.integer(
        json['quietHoursEndHour'],
        defaults.quietHoursEndHour,
      ),
      notificationOptIns: optIns,
      highFrameRateCapture: flag(
        'highFrameRateCapture',
        defaults.highFrameRateCapture,
      ),
      thermalGuard: flag('thermalGuard', defaults.thermalGuard),
      storageBudgetGb: Codecs.integer(
        json['storageBudgetGb'],
        defaults.storageBudgetGb,
      ),
      demoDataEnabled: flag('demoDataEnabled', defaults.demoDataEnabled),
      courtName: Codecs.text(json['courtName'], defaults.courtName),
    );
  }
}
