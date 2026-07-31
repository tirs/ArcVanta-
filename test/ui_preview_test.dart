import 'dart:io';

import 'package:arcvanta/core/theme/av_theme.dart';
import 'package:arcvanta/core/utils/formatters.dart';
import 'package:arcvanta/data/capture/simulated_capture_source.dart';
import 'package:arcvanta/data/models/confidence.dart';
import 'package:arcvanta/data/seed/drill_catalog.dart';
import 'package:arcvanta/data/demo/demo_data.dart';
import 'package:arcvanta/state/capture_pipeline.dart';
import 'package:arcvanta/features/auth/auth_screen.dart';
import 'package:arcvanta/features/coach/coach_home_screen.dart';
import 'package:arcvanta/features/drills/drill_library_screen.dart';
import 'package:arcvanta/features/highlights/highlights_screen.dart';
import 'package:arcvanta/features/home/home_screen.dart';
import 'package:arcvanta/features/onboarding/guardian_consent_screen.dart';
import 'package:arcvanta/features/onboarding/onboarding_screen.dart';
import 'package:arcvanta/features/onboarding/player_setup_screen.dart';
import 'package:arcvanta/features/onboarding/role_screen.dart';
import 'package:arcvanta/features/legal/legal_documents.dart';
import 'package:arcvanta/features/legal/legal_screen.dart';
import 'package:arcvanta/features/plan/training_plan_screen.dart';
import 'package:arcvanta/features/profile/profile_screen.dart';
import 'package:arcvanta/features/progress/heatmap_screen.dart';
import 'package:arcvanta/features/progress/progress_screen.dart';
import 'package:arcvanta/features/session/calibration_screen.dart';
import 'package:arcvanta/features/session/live_session_screen.dart';
import 'package:arcvanta/features/session/placement_guide_screen.dart';
import 'package:arcvanta/features/session/session_summary_screen.dart';
import 'package:arcvanta/features/session/shot_detail_screen.dart';
import 'package:arcvanta/features/subscription/subscription_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

/// Renders the app's key surfaces to PNG with the real bundled fonts so the
/// visual design can be reviewed without a device. Refresh with:
///
///     flutter test test/ui_preview_test.dart --update-goldens
/// Walks up from the running binary to the Flutter cache that holds the
/// bundled icon font.
File? _findMaterialIcons() {
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    final candidate = File(
      '${dir.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (candidate.existsSync()) return candidate;
    if (dir.parent.path == dir.path) break;
    dir = dir.parent;
  }
  return null;
}

void main() {
  // Relative dates would otherwise redraw as the wall clock moves, so every
  // preview is rendered against the same instant the seed data is built around.
  setUp(
    () => Fmt.currentTime = () => DemoData.today.add(const Duration(hours: 8)),
  );
  tearDown(() => Fmt.currentTime = DateTime.now);

  setUpAll(() async {
    TestHarness.initialiseSqlite();
    final iconFont = _findMaterialIcons();
    if (iconFont == null) {
      fail('Could not locate MaterialIcons-Regular.otf in the Flutter cache.');
    }
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(iconFont.readAsBytesSync().buffer.asByteData()),
        ))
        .load();

    for (final family in const ['Archivo', 'Inter']) {
      final loader = FontLoader(family);
      for (final weight in const [400, 500, 600, 700, 800]) {
        final file = File('assets/fonts/$family-$weight.ttf');
        if (file.existsSync()) {
          loader.addFont(
            Future.value(file.readAsBytesSync().buffer.asByteData()),
          );
        }
      }
      await loader.load();
    }
  });

  final session = DemoData.sessions.first;
  final shot = session.shots.first;
  final drill = DrillCatalog.all.first;

  final surfaces = <String, Widget>{
    '02-onboarding': const OnboardingScreen(),
    '02a-auth': const AuthScreen(),
    '02b-role': const RoleScreen(),
    '02c-player-setup': const PlayerSetupScreen(),
    '02d-guardian-consent': const GuardianConsentScreen(),
    '03-home': const HomeScreen(),
    '04-drills': const DrillLibraryScreen(),
    '05-placement': PlacementGuideScreen(drillId: drill.id),
    '06-calibration': CalibrationScreen(
      drillId: drill.id,
      angle: CameraAngle.side,
    ),
    '07-live': LiveSessionScreen(drillId: drill.id, angle: CameraAngle.side),
    '08-summary': SessionSummaryScreen(sessionId: session.id),
    '09-shot-detail': ShotDetailScreen(sessionId: session.id, shotId: shot.id),
    '10-progress': const ProgressScreen(),
    '11-heatmap': const HeatmapScreen(),
    '12-plan': const TrainingPlanScreen(),
    '13-highlights': const HighlightsScreen(),
    '14-coach': const CoachHomeScreen(),
    '15-subscription': const SubscriptionScreen(),
    '16-profile': const ProfileScreen(),
    '17-terms': const LegalScreen(document: termsOfService),
    '18-privacy-policy': const LegalScreen(document: privacyPolicy),
  };

  /// The screens whose first-run state is a design in its own right.
  ///
  /// These are the ones a new user actually lands on, and they are the
  /// screens most likely to regress: it is easy to change a populated layout
  /// and never notice what happened to the version with nothing in it.
  final firstRunSurfaces = <String, Widget>{
    '20-first-run-home': const HomeScreen(),
    '21-first-run-progress': const ProgressScreen(),
    '22-first-run-plan': const TrainingPlanScreen(),
    '23-first-run-highlights': const HighlightsScreen(),
    '24-first-run-coach': const CoachHomeScreen(),
  };

  // Previews render the sample season: the app now starts empty, and an empty
  // screen is not what these goldens are for. Opening the database has to
  // happen out here, because a widget test body runs inside a fake-async zone
  // where sqflite's real I/O never completes.
  late List<Override> storage;
  setUp(() async => storage = await TestHarness.withDemoData());

  for (final entry in surfaces.entries) {
    testWidgets('preview ${entry.key}', (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      // The capture screens run off the pipeline, so drive them from a source
      // the test controls rather than from a clock.
      final capture = ScriptedCaptureSource();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...storage,
            captureSourceProvider.overrideWithValue(capture),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AvTheme.build(),
            home: entry.value,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(seconds: 4));

      // Show the live screen mid-flight, which is the state worth reviewing.
      capture.emitFrame(ScriptedCaptureSource.frameAt(2900));
      await tester.pump();
      await tester.pump();

      // The calibration screen is worth reviewing solved, since the quality
      // report is most of what it renders. Run it the way an athlete would:
      // press the button, then feed it a scene until it settles.
      if (entry.key == '06-calibration') {
        await tester.tap(find.text('Calibrate court'));
        await tester.pump();
        for (var i = 0; i < 30; i++) {
          capture.emitSolvableScene(frame: i);
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 400));
      }

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('previews/${entry.key}.png'),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await capture.dispose();
    });
  }

  group('first run', () {
    late List<Override> emptyStorage;
    setUp(() async => emptyStorage = await TestHarness.empty());

    for (final entry in firstRunSurfaces.entries) {
      testWidgets('preview ${entry.key}', (tester) async {
        tester.view
          ..physicalSize = const Size(393, 852) * 3
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        final capture = ScriptedCaptureSource();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...emptyStorage,
              captureSourceProvider.overrideWithValue(capture),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AvTheme.build(),
              home: entry.value,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(seconds: 4));

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('previews/${entry.key}.png'),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await capture.dispose();
      });
    }
  });
}
