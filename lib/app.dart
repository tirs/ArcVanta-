import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/av_theme.dart';
import 'state/app_settings.dart';

class ArcVantaApp extends ConsumerWidget {
  const ArcVantaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'ArcVanta AI',
      debugShowCheckedModeBanner: false,
      theme: AvTheme.build(highContrast: settings.highContrast),
      routerConfig: router,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(
              (media.textScaler.scale(1) * (settings.largeText ? 1.15 : 1.0))
                  .clamp(0.85, 1.45),
            ),
            disableAnimations: settings.reducedMotion || media.disableAnimations,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
