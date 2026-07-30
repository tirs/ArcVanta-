import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import 'av_surface.dart';

enum AvButtonVariant { primary, insight, court, tonal, outline, ghost, danger }

enum AvButtonSize { small, medium, large }

/// The single button used across the product. Variants map to intent, sizes map
/// to placement: `large` for full-width commitments, `small` for inline actions.
class AvButton extends StatelessWidget {
  const AvButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AvButtonVariant.primary,
    this.size = AvButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.expand = false,
    this.busy = false,
    this.onInk = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AvButtonVariant variant;
  final AvButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool expand;
  final bool busy;

  /// Set on the dark brand surfaces. Only the variants that borrow the
  /// foreground from the page need it; the filled ones already carry their own.
  final bool onInk;

  double get _height => switch (size) {
    AvButtonSize.small => 38,
    AvButtonSize.medium => 48,
    AvButtonSize.large => 56,
  };

  double get _hPad => switch (size) {
    AvButtonSize.small => 14,
    AvButtonSize.medium => 20,
    AvButtonSize.large => 26,
  };

  TextStyle get _textStyle => switch (size) {
    AvButtonSize.small => AvType.titleSmall,
    AvButtonSize.medium => AvType.titleMedium,
    AvButtonSize.large => AvType.headingSmall.copyWith(
      fontSize: 16.5,
      letterSpacing: -0.1,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final spec = _spec(variant, onInk);
    final enabled = onPressed != null && !busy;

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(spec.foreground),
            ),
          ),
          const SizedBox(width: AvSpace.xs),
        ] else if (icon != null) ...[
          Icon(
            icon,
            size: size == AvButtonSize.small ? 16 : 19,
            color: spec.foreground,
          ),
          const SizedBox(width: AvSpace.xs),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _textStyle.copyWith(color: spec.foreground),
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: AvSpace.xs),
          Icon(trailingIcon, size: 18, color: spec.foreground),
        ],
      ],
    );

    return AvPressable(
      onTap: onPressed,
      enabled: enabled,
      borderRadius: AvRadius.pill,
      semanticLabel: label,
      child: Container(
        height: _height,
        width: expand ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: _hPad),
        // A null alignment lets the container shrink to the label when the
        // button is placed in a loose slot such as a Wrap.
        alignment: expand ? Alignment.center : null,
        decoration: BoxDecoration(
          gradient: spec.gradient,
          color: spec.background,
          borderRadius: AvRadius.pill,
          border: spec.borderColor == null
              ? null
              : Border.all(color: spec.borderColor!, width: 1.4),
          boxShadow: spec.glow == null || !enabled
              ? null
              : AvShadow.glow(spec.glow!),
        ),
        child: child,
      ),
    );
  }

  static _ButtonSpec _spec(AvButtonVariant variant, bool onInk) =>
      switch (variant) {
        AvButtonVariant.primary => const _ButtonSpec(
          gradient: AvGradients.flare,
          foreground: Colors.white,
          glow: AvColors.flare,
        ),
        AvButtonVariant.insight => const _ButtonSpec(
          gradient: AvGradients.insight,
          foreground: Colors.white,
          glow: AvColors.insight,
        ),
        AvButtonVariant.court => const _ButtonSpec(
          gradient: AvGradients.court,
          foreground: Colors.white,
          glow: AvColors.court,
        ),
        AvButtonVariant.tonal => const _ButtonSpec(
          background: AvColors.ink,
          foreground: AvColors.textOnInk,
        ),
        AvButtonVariant.outline => _ButtonSpec(
          background: Colors.transparent,
          foreground: onInk ? AvColors.textOnInk : AvColors.textPrimary,
          borderColor: onInk ? AvColors.hairlineOnInk : AvColors.hairlineStrong,
        ),
        AvButtonVariant.ghost => _ButtonSpec(
          background: Colors.transparent,
          foreground: onInk ? AvColors.textOnInk : AvColors.insight,
        ),
        AvButtonVariant.danger => const _ButtonSpec(
          background: AvColors.criticalSoft,
          foreground: AvColors.critical,
        ),
      };
}

class _ButtonSpec {
  const _ButtonSpec({
    this.gradient,
    this.background,
    required this.foreground,
    this.borderColor,
    this.glow,
  });

  final Gradient? gradient;
  final Color? background;
  final Color foreground;
  final Color? borderColor;
  final Color? glow;
}

/// Square icon action with an optional badge count.
class AvIconButton extends StatelessWidget {
  const AvIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color = AvColors.textPrimary,
    this.background = AvColors.surface,
    this.borderColor = AvColors.hairline,
    this.size = 42,
    this.badgeCount,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color color;
  final Color background;
  final Color? borderColor;
  final double size;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    Widget button = AvPressable(
      onTap: onPressed,
      borderRadius: AvRadius.allSm,
      semanticLabel: tooltip,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: AvRadius.allSm,
          border: borderColor == null ? null : Border.all(color: borderColor!),
        ),
        child: Icon(icon, size: size * 0.48, color: color),
      ),
    );

    if (badgeCount != null && badgeCount! > 0) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AvColors.flare,
                borderRadius: AvRadius.pill,
                border: Border.all(color: AvColors.canvas, width: 2),
              ),
              child: Text(
                badgeCount! > 99 ? '99+' : '$badgeCount',
                style: AvType.overline.copyWith(
                  color: Colors.white,
                  letterSpacing: 0,
                  fontSize: 9.5,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Text-only action used inside card headers.
class AvTextAction extends StatelessWidget {
  const AvTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.color = AvColors.insight,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AvPressable(
      onTap: onPressed,
      borderRadius: AvRadius.allXs,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AvType.titleSmall.copyWith(color: color),
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 15, color: color),
            ],
          ],
        ),
      ),
    );
  }
}
