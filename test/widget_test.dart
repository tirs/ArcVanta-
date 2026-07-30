import 'package:arcvanta/app.dart';
import 'package:arcvanta/design/components/av_brand.dart';
import 'package:arcvanta/features/onboarding/onboarding_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('launch screen leads into onboarding', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ArcVantaApp()));
    await tester.pump();

    expect(find.byType(AvWordmark), findsOneWidget);
    expect(find.text('Advanced basketball intelligence'), findsOneWidget);

    // Drain the startup checks the splash performs before routing.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
