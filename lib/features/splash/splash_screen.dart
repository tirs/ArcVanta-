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

/// Launch screen. Runs the startup checks the product performs before the first
/// frame of content: entitlement refresh, model manifest and local store.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _steps = [
    'Restoring local session store',
    'Verifying entitlement',
    'Loading model manifest',
    'Preparing camera pipeline',
  ];

  late final AnimationController _controller;
  int _step = 0;

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
    for (var i = 0; i < _steps.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 380));
      if (!mounted) return;
      setState(() => _step = i + 1);
    }
    await Future<void>.delayed(const Duration(milliseconds: 320));
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
            for (var i = 0; i < _steps.length; i++)
              _StepRow(label: _steps[i], done: _step > i),
            const SizedBox(height: AvSpace.xl),
            Text(
              'Live analysis runs on this device. Video leaves the phone '
              'only when you ask for cloud review.',
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
