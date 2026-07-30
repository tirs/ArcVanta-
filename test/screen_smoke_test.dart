import 'package:arcvanta/core/theme/av_theme.dart';
import 'package:arcvanta/core/utils/formatters.dart';
import 'package:arcvanta/data/capture/simulated_capture_source.dart';
import 'package:arcvanta/data/models/confidence.dart';
import 'package:arcvanta/data/seed/drill_catalog.dart';
import 'package:arcvanta/data/seed/seed_data.dart';
import 'package:arcvanta/features/auth/auth_screen.dart';
import 'package:arcvanta/features/coach/assignment_creator_screen.dart';
import 'package:arcvanta/features/coach/athlete_detail_screen.dart';
import 'package:arcvanta/features/coach/coach_home_screen.dart';
import 'package:arcvanta/features/coach/review_queue_screen.dart';
import 'package:arcvanta/features/coach/team_dashboard_screen.dart';
import 'package:arcvanta/features/drills/drill_builder_screen.dart';
import 'package:arcvanta/features/drills/drill_detail_screen.dart';
import 'package:arcvanta/features/drills/drill_library_screen.dart';
import 'package:arcvanta/features/highlights/highlights_screen.dart';
import 'package:arcvanta/features/session/live_session_screen.dart';
import 'package:arcvanta/features/home/home_screen.dart';
import 'package:arcvanta/features/notifications/notifications_screen.dart';
import 'package:arcvanta/features/onboarding/guardian_consent_screen.dart';
import 'package:arcvanta/features/onboarding/onboarding_screen.dart';
import 'package:arcvanta/features/onboarding/player_setup_screen.dart';
import 'package:arcvanta/features/onboarding/role_screen.dart';
import 'package:arcvanta/features/plan/goals_screen.dart';
import 'package:arcvanta/features/plan/training_plan_screen.dart';
import 'package:arcvanta/features/profile/device_settings_screen.dart';
import 'package:arcvanta/features/profile/help_screen.dart';
import 'package:arcvanta/features/profile/privacy_screen.dart';
import 'package:arcvanta/features/profile/profile_screen.dart';
import 'package:arcvanta/features/progress/heatmap_screen.dart';
import 'package:arcvanta/features/progress/progress_screen.dart';
import 'package:arcvanta/features/session/calibration_screen.dart';
import 'package:arcvanta/features/session/comparison_screen.dart';
import 'package:arcvanta/features/session/placement_guide_screen.dart';
import 'package:arcvanta/features/session/session_history_screen.dart';
import 'package:arcvanta/features/session/session_summary_screen.dart';
import 'package:arcvanta/features/session/shot_detail_screen.dart';
import 'package:arcvanta/features/session/shot_timeline_screen.dart';
import 'package:arcvanta/features/subscription/subscription_screen.dart';
import 'package:arcvanta/state/live_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mounts every screen at a handful of realistic viewport sizes. Layout
/// overflow and paint errors are reported as test failures, which is the only
/// way to catch them without a device in the loop.
void main() {
  final session = SeedData.sessions.first;
  final shot = session.shots.first;
  final drill = DrillCatalog.all.first;
  final athlete = SeedData.roster.first;

  final screens = <String, Widget>{
    'onboarding': const OnboardingScreen(),
    'auth': const AuthScreen(),
    'role': const RoleScreen(),
    'player setup': const PlayerSetupScreen(),
    'guardian consent': const GuardianConsentScreen(),
    'home': const HomeScreen(),
    'drill library': const DrillLibraryScreen(),
    'drill detail': DrillDetailScreen(drillId: drill.id),
    'drill builder': const DrillBuilderScreen(),
    'placement': PlacementGuideScreen(drillId: drill.id),
    'calibration': CalibrationScreen(
      drillId: drill.id,
      angle: CameraAngle.side,
    ),
    'live session': LiveSessionScreen(
      drillId: drill.id,
      angle: CameraAngle.side,
    ),
    'session summary': SessionSummaryScreen(sessionId: session.id),
    'shot timeline': ShotTimelineScreen(sessionId: session.id),
    'shot detail': ShotDetailScreen(sessionId: session.id, shotId: shot.id),
    'comparison': ComparisonScreen(sessionId: session.id, shotId: shot.id),
    'session history': const SessionHistoryScreen(),
    'progress': const ProgressScreen(),
    'heatmap': const HeatmapScreen(),
    'training plan': const TrainingPlanScreen(),
    'goals': const GoalsScreen(),
    'highlights': const HighlightsScreen(),
    'coach home': const CoachHomeScreen(),
    'athlete detail': AthleteDetailScreen(athleteId: athlete.id),
    'review queue': const ReviewQueueScreen(),
    'team dashboard': const TeamDashboardScreen(),
    'assignment creator': AssignmentCreatorScreen(athleteId: athlete.id),
    'notifications': const NotificationsScreen(),
    'subscription': const SubscriptionScreen(),
    'profile': const ProfileScreen(),
    'privacy': const PrivacyScreen(),
    'device settings': const DeviceSettingsScreen(),
    'help': const HelpScreen(),
  };

  // The smallest and largest phones still sold, plus the text scales the
  // platform accessibility settings actually reach. Anything that overflows in
  // one of these overflows on somebody's device.
  const viewports = <String, ({Size size, double textScale})>{
    'small phone': (size: Size(320, 568), textScale: 1),
    'compact phone': (size: Size(360, 640), textScale: 1),
    'standard phone': (size: Size(393, 852), textScale: 1),
    'large phone': (size: Size(430, 932), textScale: 1),
    'large text': (size: Size(393, 852), textScale: 1.3),
    'largest text': (size: Size(360, 800), textScale: 1.6),
    'landscape': (size: Size(852, 393), textScale: 1),
  };

  for (final viewport in viewports.entries) {
    group(viewport.key, () {
      for (final entry in screens.entries) {
        testWidgets('${entry.key} renders', (tester) async {
          tester.view
            ..physicalSize = viewport.value.size * 3
            ..devicePixelRatio = 3;
          addTearDown(tester.view.reset);

          // Every screen is mounted against a pipeline the test owns, so none
          // of them depend on a running clock.
          final capture = ScriptedCaptureSource();
          Fmt.currentTime = () => SeedData.today.add(const Duration(hours: 8));
          addTearDown(() {
            Fmt.currentTime = DateTime.now;
            return capture.dispose();
          });

          await tester.pumpWidget(
            ProviderScope(
              overrides: [captureSourceProvider.overrideWithValue(capture)],
              child: MaterialApp(
                theme: AvTheme.build(),
                builder: (context, child) => MediaQuery.withClampedTextScaling(
                  minScaleFactor: viewport.value.textScale,
                  maxScaleFactor: viewport.value.textScale,
                  child: child!,
                ),
                home: entry.value,
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 500));

          // Push the capture screens through a full shot so their live states
          // are laid out too, not just their empty ones.
          await tester.pump(const Duration(seconds: 4));
          for (final ms in const [600, 1800, 2600, 2900, 3600, 4400]) {
            capture.emitFrame(ScriptedCaptureSource.frameAt(ms));
            await tester.pump(const Duration(milliseconds: 16));
          }
          capture.emitShot(session.shots.first);
          await tester.pump(const Duration(milliseconds: 16));
          await tester.pump(const Duration(seconds: 2));

          // Tearing the tree down before the frame is reported would strip the
          // widget creator from any layout error, so settle first.
          await tester.pump();
          addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
        });
      }
    });
  }
}
