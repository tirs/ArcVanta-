import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/confidence.dart';
import '../data/models/profile.dart';
import '../data/store/repository.dart';
import '../data/store/settings_codec.dart';
import 'bootstrap.dart';

enum FeedbackFrequency {
  off,
  sparse,
  balanced,
  detailed;

  String get label => switch (this) {
    FeedbackFrequency.off => 'Off',
    FeedbackFrequency.sparse => 'Only between sets',
    FeedbackFrequency.balanced => 'Every few attempts',
    FeedbackFrequency.detailed => 'Every attempt',
  };

  /// How many attempts have to pass before another cue is allowed.
  ///
  /// A cue during the shot before last is noise: the athlete has already
  /// changed something by the time they hear it. The gap is what turns a
  /// stream of measurements into coaching.
  int get attemptsBetweenCues => switch (this) {
    FeedbackFrequency.off => 1 << 30,
    FeedbackFrequency.sparse => 10,
    FeedbackFrequency.balanced => 4,
    FeedbackFrequency.detailed => 1,
  };
}

enum RetentionWindow {
  sevenDays,
  thirtyDays,
  ninetyDays,
  untilDeleted;

  String get label => switch (this) {
    RetentionWindow.sevenDays => '7 days',
    RetentionWindow.thirtyDays => '30 days',
    RetentionWindow.ninetyDays => '90 days',
    RetentionWindow.untilDeleted => 'Until I delete it',
  };
}

class AppSettings {
  const AppSettings({
    this.onboardingComplete = false,
    this.role = AccountRole.player,
    this.guestMode = false,
    this.preferredAngle = CameraAngle.side,
    this.spokenFeedback = true,
    this.hapticFeedback = true,
    this.feedbackFrequency = FeedbackFrequency.balanced,
    this.showOverlays = true,
    this.showSkeleton = true,
    this.showTrajectory = true,
    this.showZones = true,
    this.highContrast = false,
    this.reducedMotion = false,
    this.largeText = false,
    this.leftHandedLayout = false,
    this.captionsForAudioCoaching = true,
    this.localProcessingOnly = true,
    this.cloudBackup = false,
    this.modelTrainingConsent = false,
    this.retention = RetentionWindow.thirtyDays,
    this.quietHoursEnabled = true,
    this.quietHoursStartHour = 21,
    this.quietHoursEndHour = 7,
    this.notificationOptIns = const {
      'training': true,
      'assignment': true,
      'progress': true,
      'analysis': true,
      'account': true,
      'safety': true,
    },
    this.highFrameRateCapture = true,
    this.thermalGuard = true,
    this.storageBudgetGb = 12,
    this.demoDataEnabled = false,
    this.courtName = '',
  });

  final bool onboardingComplete;
  final AccountRole role;
  final bool guestMode;
  final CameraAngle preferredAngle;

  final bool spokenFeedback;
  final bool hapticFeedback;
  final FeedbackFrequency feedbackFrequency;

  final bool showOverlays;
  final bool showSkeleton;
  final bool showTrajectory;
  final bool showZones;

  final bool highContrast;
  final bool reducedMotion;
  final bool largeText;
  final bool leftHandedLayout;
  final bool captionsForAudioCoaching;

  final bool localProcessingOnly;
  final bool cloudBackup;
  final bool modelTrainingConsent;
  final RetentionWindow retention;

  final bool quietHoursEnabled;
  final int quietHoursStartHour;
  final int quietHoursEndHour;
  final Map<String, bool> notificationOptIns;

  final bool highFrameRateCapture;
  final bool thermalGuard;
  final int storageBudgetGb;

  /// Whether the sample history is loaded alongside the user's own.
  ///
  /// Off unless the user turns it on in Settings. Demo sessions are marked in
  /// storage and never counted into a real total, so this can never quietly
  /// inflate what someone thinks they shot.
  final bool demoDataEnabled;

  /// What the athlete calls the place they shoot. Empty until they name it;
  /// sessions recorded before then say so rather than inventing a venue.
  final String courtName;

  bool get isCoachRole =>
      role == AccountRole.coach ||
      role == AccountRole.trainer ||
      role == AccountRole.organizationAdmin;

  AppSettings copyWith({
    bool? onboardingComplete,
    AccountRole? role,
    bool? guestMode,
    CameraAngle? preferredAngle,
    bool? spokenFeedback,
    bool? hapticFeedback,
    FeedbackFrequency? feedbackFrequency,
    bool? showOverlays,
    bool? showSkeleton,
    bool? showTrajectory,
    bool? showZones,
    bool? highContrast,
    bool? reducedMotion,
    bool? largeText,
    bool? leftHandedLayout,
    bool? captionsForAudioCoaching,
    bool? localProcessingOnly,
    bool? cloudBackup,
    bool? modelTrainingConsent,
    RetentionWindow? retention,
    bool? quietHoursEnabled,
    int? quietHoursStartHour,
    int? quietHoursEndHour,
    Map<String, bool>? notificationOptIns,
    bool? highFrameRateCapture,
    bool? thermalGuard,
    int? storageBudgetGb,
    bool? demoDataEnabled,
    String? courtName,
  }) {
    return AppSettings(
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      role: role ?? this.role,
      guestMode: guestMode ?? this.guestMode,
      preferredAngle: preferredAngle ?? this.preferredAngle,
      spokenFeedback: spokenFeedback ?? this.spokenFeedback,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      feedbackFrequency: feedbackFrequency ?? this.feedbackFrequency,
      showOverlays: showOverlays ?? this.showOverlays,
      showSkeleton: showSkeleton ?? this.showSkeleton,
      showTrajectory: showTrajectory ?? this.showTrajectory,
      showZones: showZones ?? this.showZones,
      highContrast: highContrast ?? this.highContrast,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      largeText: largeText ?? this.largeText,
      leftHandedLayout: leftHandedLayout ?? this.leftHandedLayout,
      captionsForAudioCoaching:
          captionsForAudioCoaching ?? this.captionsForAudioCoaching,
      localProcessingOnly: localProcessingOnly ?? this.localProcessingOnly,
      cloudBackup: cloudBackup ?? this.cloudBackup,
      modelTrainingConsent: modelTrainingConsent ?? this.modelTrainingConsent,
      retention: retention ?? this.retention,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStartHour: quietHoursStartHour ?? this.quietHoursStartHour,
      quietHoursEndHour: quietHoursEndHour ?? this.quietHoursEndHour,
      notificationOptIns: notificationOptIns ?? this.notificationOptIns,
      highFrameRateCapture: highFrameRateCapture ?? this.highFrameRateCapture,
      thermalGuard: thermalGuard ?? this.thermalGuard,
      storageBudgetGb: storageBudgetGb ?? this.storageBudgetGb,
      demoDataEnabled: demoDataEnabled ?? this.demoDataEnabled,
      courtName: courtName ?? this.courtName,
    );
  }
}

class AppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(appSnapshotProvider).settings;

  void completeOnboarding() => _set(state.copyWith(onboardingComplete: true));

  void setRole(AccountRole role) => _set(state.copyWith(role: role));

  void setGuestMode(bool value) => _set(state.copyWith(guestMode: value));

  void setPreferredAngle(CameraAngle angle) =>
      _set(state.copyWith(preferredAngle: angle));

  void update(AppSettings Function(AppSettings current) transform) =>
      _set(transform(state));

  void setNotificationOptIn(String key, bool value) {
    final next = Map<String, bool>.from(state.notificationOptIns);
    next[key] = value;
    _set(state.copyWith(notificationOptIns: next));
  }

  void reset() => _set(const AppSettings());

  void _set(AppSettings next) {
    state = next;
    ref
        .read(repositoryProvider)
        .writeDocument(DocumentKey.settings, SettingsCodec.toJson(next));
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

/// What to label a session's venue with.
///
/// Falls back to a plain statement of ignorance rather than a placeholder that
/// reads like a real gym, because a stored session is evidence and a made-up
/// location is the kind of detail nobody thinks to question later.
final courtNameProvider = Provider<String>((ref) {
  final name = ref.watch(appSettingsProvider).courtName.trim();
  return name.isEmpty ? 'Unnamed court' : name;
});
