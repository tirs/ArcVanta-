import 'dart:io';

import 'package:arcvanta/core/theme/av_theme.dart';
import 'package:arcvanta/data/models/confidence.dart';
import 'package:arcvanta/data/seed/drill_catalog.dart';
import 'package:arcvanta/data/seed/seed_data.dart';
import 'package:arcvanta/features/coach/coach_home_screen.dart';
import 'package:arcvanta/features/drills/drill_library_screen.dart';
import 'package:arcvanta/features/highlights/highlights_screen.dart';
import 'package:arcvanta/features/home/home_screen.dart';
import 'package:arcvanta/features/onboarding/onboarding_screen.dart';
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
  setUpAll(() async {
    final iconFont = _findMaterialIcons();
    if (iconFont == null) {
      fail('Could not locate MaterialIcons-Regular.otf in the Flutter cache.');
    }
    await (FontLoader('MaterialIcons')
          ..addFont(
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

  final session = SeedData.sessions.first;
  final shot = session.shots.first;
  final drill = DrillCatalog.all.first;

  final surfaces = <String, Widget>{
    '02-onboarding': const OnboardingScreen(),
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
  };

  for (final entry in surfaces.entries) {
    testWidgets('preview ${entry.key}', (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AvTheme.build(),
            home: entry.value,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(seconds: 2));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('previews/${entry.key}.png'),
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
