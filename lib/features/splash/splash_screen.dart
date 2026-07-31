import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../design/components/av_brand.dart';
import '../../design/components/av_brand_scaffold.dart';
import '../../state/app_settings.dart';
import '../../state/capture_pipeline.dart';

/// Launch screen.
///
/// The two lines it shows are the two things that genuinely have to finish
/// before the app is usable: the stored history is read off disk, and the
/// platform is asked whether it can run the analysis models. Both are real
/// futures, so the screen leaves as soon as they land rather than sitting
/// through a scripted delay.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// The logo draw. Nothing waits on it, but leaving before it finishes looks
  /// like a crash, so it is the floor on how long the screen stays up.
  static const _minimumVisible = Duration(milliseconds: 1100);

  late final AnimationController _controller;

  bool _storeReady = false;
  bool _pipelineChecked = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _advance();
  }

  Future<void> _advance() async {
    final floor = Future<void>.delayed(_minimumVisible);

    // The store is already open by the time the first frame runs: main() waits
    // for it so no screen has to render over a loading state. Reading it here
    // is what confirms that, rather than asserting it.
    ref.read(appSettingsProvider);
    if (mounted) setState(() => _storeReady = true);

    await ref.read(pipelineStatusProvider.future);
    if (mounted) setState(() => _pipelineChecked = true);

    await floor;
    if (!mounted) return;

    final settings = ref.read(appSettingsProvider);
    context.go(
      settings.onboardingComplete ? AppRoute.home : AppRoute.onboarding,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AvBrandScaffold(
      child: Padding(
        padding: const EdgeInsets.all(AvSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => AvLogoMark(
                size: 76,
                progress: Curves.easeOutCubic.transform(_controller.value),
              ),
            ),
            const SizedBox(height: AvSpace.xl),
            const AvWordmark(fontSize: 38, onInk: true),
            const SizedBox(height: AvSpace.sm),
            Text(
              'Advanced basketball intelligence',
              style: AvType.body.onInkMuted,
            ),
            const Spacer(),
            _StepRow(label: 'Reading your history', done: _storeReady),
            _StepRow(
              label: 'Checking the analysis pipeline',
              done: _pipelineChecked,
            ),
            const SizedBox(height: AvSpace.xl),
            Text(
              'Live analysis runs on this device. Nothing you record is '
              'sent anywhere.',
              style: AvType.caption.copyWith(
                color: AvColors.textOnInkMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          AnimatedContainer(
            duration: AvMotion.normal,
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: done
                  ? AvColors.made
                  : Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: done
                    ? AvColors.made
                    : Colors.white.withValues(alpha: 0.22),
              ),
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: AvSpace.sm),
          AnimatedDefaultTextStyle(
            duration: AvMotion.normal,
            style: AvType.bodySmall.copyWith(
              color: done ? AvColors.textOnInk : AvColors.textOnInkMuted,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
