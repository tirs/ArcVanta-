import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/confidence.dart';
import '../data/models/profile.dart';

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
    );
  }
}

class AppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void completeOnboarding() => state = state.copyWith(onboardingComplete: true);

  void setRole(AccountRole role) => state = state.copyWith(role: role);

  void setGuestMode(bool value) => state = state.copyWith(guestMode: value);

  void setPreferredAngle(CameraAngle angle) =>
      state = state.copyWith(preferredAngle: angle);

  void update(AppSettings Function(AppSettings current) transform) =>
      state = transform(state);

  void setNotificationOptIn(String key, bool value) {
    final next = Map<String, bool>.from(state.notificationOptIns);
    next[key] = value;
    state = state.copyWith(notificationOptIns: next);
  }

  void reset() => state = const AppSettings();
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );
