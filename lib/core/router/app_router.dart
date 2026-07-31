import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/confidence.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/coach/assignment_creator_screen.dart';
import '../../features/coach/athlete_detail_screen.dart';
import '../../features/coach/coach_home_screen.dart';
import '../../features/coach/review_queue_screen.dart';
import '../../features/coach/team_dashboard_screen.dart';
import '../../features/drills/drill_builder_screen.dart';
import '../../features/drills/drill_detail_screen.dart';
import '../../features/drills/drill_library_screen.dart';
import '../../features/highlights/highlights_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/onboarding/guardian_consent_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/player_setup_screen.dart';
import '../../features/onboarding/role_screen.dart';
import '../../features/legal/legal_documents.dart';
import '../../features/legal/legal_screen.dart';
import '../../features/plan/goals_screen.dart';
import '../../features/plan/training_plan_screen.dart';
import '../../features/profile/device_settings_screen.dart';
import '../../features/profile/help_screen.dart';
import '../../features/profile/privacy_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/progress/heatmap_screen.dart';
import '../../features/progress/progress_screen.dart';
import '../../features/session/calibration_screen.dart';
import '../../features/session/comparison_screen.dart';
import '../../features/session/live_session_screen.dart';
import '../../features/session/placement_guide_screen.dart';
import '../../features/session/session_history_screen.dart';
import '../../features/session/session_summary_screen.dart';
import '../../features/session/shot_detail_screen.dart';
import '../../features/session/shot_timeline_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/subscription/subscription_screen.dart';
import '../../state/app_settings.dart';

abstract final class AppRoute {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const auth = '/auth';
  static const role = '/role';
  static const playerSetup = '/player-setup';
  static const guardianConsent = '/guardian-consent';

  static const home = '/home';
  static const train = '/train';
  static const progress = '/progress';
  static const coach = '/coach';
  static const profile = '/profile';

  static const drills = '/train';
  static const drillBuilder = '/train/builder';
  static const sessions = '/sessions';
  static const heatmap = '/heatmap';
  static const plan = '/plan';
  static const goals = '/goals';
  static const highlights = '/highlights';
  static const notifications = '/notifications';
  static const subscription = '/subscription';
  static const privacy = '/privacy';
  static const device = '/device';
  static const help = '/help';
  static const terms = '/legal/terms';
  static const privacyPolicy = '/legal/privacy';
  static const reviewQueue = '/coach/reviews';
  static const team = '/coach/team';
  static const assign = '/coach/assign';

  static String drill(String id) => '/train/drill/$id';
  static String placement(String drillId) => '/session/placement/$drillId';
  static String calibration(String drillId, CameraAngle angle) =>
      '/session/calibration/$drillId?angle=${angle.name}';
  static String live(String drillId, CameraAngle angle) =>
      '/session/live/$drillId?angle=${angle.name}';
  static String session(String id) => '/sessions/$id';
  static String timeline(String id) => '/sessions/$id/timeline';
  static String shot(String sessionId, String shotId) =>
      '/sessions/$sessionId/shot/$shotId';
  static String compare(String sessionId, String shotId) =>
      '/sessions/$sessionId/compare/$shotId';
  static String athlete(String id) => '/coach/athlete/$id';
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppRoute.splash,
    routes: [
      GoRoute(
        path: AppRoute.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoute.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoute.auth,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: AppRoute.role,
        builder: (context, state) => const RoleScreen(),
      ),
      GoRoute(
        path: AppRoute.playerSetup,
        builder: (context, state) => const PlayerSetupScreen(),
      ),
      GoRoute(
        path: AppRoute.guardianConsent,
        builder: (context, state) => const GuardianConsentScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.train,
                builder: (context, state) => const DrillLibraryScreen(),
                routes: [
                  GoRoute(
                    path: 'builder',
                    builder: (context, state) => const DrillBuilderScreen(),
                  ),
                  GoRoute(
                    path: 'drill/:id',
                    builder: (context, state) =>
                        DrillDetailScreen(drillId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.progress,
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.coach,
                builder: (context, state) => const CoachHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'reviews',
                    builder: (context, state) => const ReviewQueueScreen(),
                  ),
                  GoRoute(
                    path: 'team',
                    builder: (context, state) => const TeamDashboardScreen(),
                  ),
                  GoRoute(
                    path: 'assign',
                    builder: (context, state) => AssignmentCreatorScreen(
                      athleteId: state.uri.queryParameters['athlete'],
                    ),
                  ),
                  GoRoute(
                    path: 'athlete/:id',
                    builder: (context, state) => AthleteDetailScreen(
                      athleteId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/session/placement/:drillId',
        parentNavigatorKey: _rootKey,
        builder: (context, state) =>
            PlacementGuideScreen(drillId: state.pathParameters['drillId']!),
      ),
      GoRoute(
        path: '/session/calibration/:drillId',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => CalibrationScreen(
          drillId: state.pathParameters['drillId']!,
          angle: _angle(state.uri.queryParameters['angle']),
        ),
      ),
      GoRoute(
        path: '/session/live/:drillId',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => LiveSessionScreen(
          drillId: state.pathParameters['drillId']!,
          angle: _angle(state.uri.queryParameters['angle']),
        ),
      ),
      GoRoute(
        path: AppRoute.sessions,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SessionHistoryScreen(),
      ),
      GoRoute(
        path: '/sessions/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) =>
            SessionSummaryScreen(sessionId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'timeline',
            parentNavigatorKey: _rootKey,
            builder: (context, state) =>
                ShotTimelineScreen(sessionId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'shot/:shotId',
            parentNavigatorKey: _rootKey,
            builder: (context, state) => ShotDetailScreen(
              sessionId: state.pathParameters['id']!,
              shotId: state.pathParameters['shotId']!,
            ),
          ),
          GoRoute(
            path: 'compare/:shotId',
            parentNavigatorKey: _rootKey,
            builder: (context, state) => ComparisonScreen(
              sessionId: state.pathParameters['id']!,
              shotId: state.pathParameters['shotId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoute.terms,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const LegalScreen(document: termsOfService),
      ),
      GoRoute(
        path: AppRoute.privacyPolicy,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const LegalScreen(document: privacyPolicy),
      ),
      GoRoute(
        path: AppRoute.heatmap,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const HeatmapScreen(),
      ),
      GoRoute(
        path: AppRoute.plan,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const TrainingPlanScreen(),
      ),
      GoRoute(
        path: AppRoute.goals,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const GoalsScreen(),
      ),
      GoRoute(
        path: AppRoute.highlights,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const HighlightsScreen(),
      ),
      GoRoute(
        path: AppRoute.notifications,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoute.subscription,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: AppRoute.privacy,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: AppRoute.device,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const DeviceSettingsScreen(),
      ),
      GoRoute(
        path: AppRoute.help,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const HelpScreen(),
      ),
    ],
    redirect: (context, state) {
      final settings = ref.read(appSettingsProvider);
      const publicRoutes = {
        AppRoute.splash,
        AppRoute.onboarding,
        AppRoute.auth,
        AppRoute.role,
        AppRoute.playerSetup,
        AppRoute.guardianConsent,
      };
      final path = state.uri.path;
      if (!settings.onboardingComplete && !publicRoutes.contains(path)) {
        return AppRoute.splash;
      }
      return null;
    },
  );
});

CameraAngle _angle(String? name) => CameraAngle.values.firstWhere(
  (a) => a.name == name,
  orElse: () => CameraAngle.side,
);
