import 'package:arcvanta/app.dart';
import 'package:arcvanta/design/components/av_brand.dart';
import 'package:arcvanta/features/onboarding/onboarding_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  TestHarness.initialiseSqlite();

  late List<Override> storage;
  setUp(() async => storage = await TestHarness.empty());

  testWidgets('launch screen leads into onboarding', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: storage, child: const ArcVantaApp()),
    );
    await tester.pump();

    expect(find.byType(AvWordmark), findsOneWidget);
    expect(find.text('Advanced basketball intelligence'), findsOneWidget);

    // The splash waits on the pipeline check and on its own minimum display
    // time, neither of which a single pump will clear.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
