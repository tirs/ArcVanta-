import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'av_colors.dart';
import 'av_tokens.dart';
import 'av_typography.dart';

abstract final class AvTheme {
  static const SystemUiOverlayStyle lightOverlay = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AvColors.canvas,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static const SystemUiOverlayStyle inkOverlay = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AvColors.ink,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData build({bool highContrast = false}) {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AvColors.flare,
      onPrimary: Colors.white,
      primaryContainer: AvColors.flareSoft,
      onPrimaryContainer: AvColors.flareDeep,
      secondary: AvColors.insight,
      onSecondary: Colors.white,
      secondaryContainer: AvColors.insightSoft,
      onSecondaryContainer: AvColors.insightDeep,
      tertiary: AvColors.court,
      onTertiary: Colors.white,
      tertiaryContainer: AvColors.courtSoft,
      onTertiaryContainer: AvColors.courtDeep,
      error: AvColors.critical,
      onError: Colors.white,
      errorContainer: AvColors.criticalSoft,
      onErrorContainer: AvColors.critical,
      surface: AvColors.surface,
      onSurface: AvColors.textPrimary,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: AvColors.surfaceMuted,
      surfaceContainer: AvColors.canvas,
      surfaceContainerHigh: AvColors.canvasSunken,
      surfaceContainerHighest: AvColors.canvasSunken,
      onSurfaceVariant: highContrast
          ? AvColors.textSecondary
          : AvColors.textMuted,
      outline: highContrast ? AvColors.hairlineStrong : AvColors.hairline,
      outlineVariant: AvColors.hairline,
      inverseSurface: AvColors.ink,
      onInverseSurface: AvColors.textOnInk,
      inversePrimary: AvColors.flareSoft,
      shadow: const Color(0x332B2416),
      scrim: const Color(0x99141322),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AvColors.canvas,
      canvasColor: AvColors.canvas,
      fontFamily: AvType.text,
      textTheme: AvType.textTheme.apply(
        bodyColor: AvColors.textPrimary,
        displayColor: AvColors.textPrimary,
      ),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AvColors.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AvColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: lightOverlay,
        titleTextStyle: TextStyle(
          fontFamily: AvType.display,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: AvColors.textPrimary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AvColors.hairline,
        space: 1,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: AvColors.textSecondary, size: 22),
      cardTheme: const CardThemeData(
        color: AvColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AvColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AvColors.surface,
        showDragHandle: true,
        dragHandleColor: AvColors.hairlineStrong,
        dragHandleSize: Size(38, 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: AvRadius.xl),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AvColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AvRadius.allLg),
        titleTextStyle: TextStyle(
          fontFamily: AvType.display,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.35,
          color: AvColors.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontFamily: AvType.text,
          fontSize: 14.5,
          height: 1.5,
          color: AvColors.textSecondary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AvColors.ink,
        contentTextStyle: AvType.bodySmall.copyWith(
          color: AvColors.textOnInk,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: AvColors.flare,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AvSpace.md),
        shape: const RoundedRectangleBorder(borderRadius: AvRadius.allMd),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: AvColors.ink,
          borderRadius: AvRadius.allXs,
        ),
        textStyle: AvType.caption.copyWith(color: AvColors.textOnInk),
        padding: const EdgeInsets.symmetric(
          horizontal: AvSpace.sm,
          vertical: 6,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AvColors.flare,
        inactiveTrackColor: AvColors.hairline,
        thumbColor: Colors.white,
        overlayColor: AvColors.flare.withValues(alpha: 0.12),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 11,
          elevation: 2,
          pressedElevation: 3,
        ),
        valueIndicatorColor: AvColors.ink,
        valueIndicatorTextStyle: AvType.label.copyWith(color: Colors.white),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AvColors.made
              : AvColors.hairlineStrong,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbIcon: const WidgetStatePropertyAll(Icon(null)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AvColors.insight
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: AvColors.hairlineStrong, width: 1.6),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AvColors.insight
              : AvColors.hairlineStrong,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AvColors.flare,
        linearTrackColor: AvColors.hairline,
        circularTrackColor: AvColors.hairline,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AvColors.surface,
        hintStyle: AvType.body.copyWith(color: AvColors.textFaint),
        labelStyle: AvType.label.copyWith(color: AvColors.textMuted),
        floatingLabelStyle: AvType.label.copyWith(color: AvColors.insight),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AvSpace.md,
          vertical: AvSpace.md,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AvRadius.allMd,
          borderSide: BorderSide(color: AvColors.hairline, width: 1.2),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AvRadius.allMd,
          borderSide: BorderSide(color: AvColors.insight, width: 1.8),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AvRadius.allMd,
          borderSide: BorderSide(color: AvColors.critical, width: 1.4),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AvRadius.allMd,
          borderSide: BorderSide(color: AvColors.critical, width: 1.8),
        ),
        errorStyle: AvType.caption.copyWith(color: AvColors.critical),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AvColors.insight,
        selectionColor: AvColors.insight.withValues(alpha: 0.2),
        selectionHandleColor: AvColors.insight,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
