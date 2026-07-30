import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_theme.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import 'av_button.dart';
import 'av_surface.dart';

/// Page scaffold with the product's standard header treatment.
class AvScaffold extends StatelessWidget {
  const AvScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.bottomBar,
    this.background = AvColors.canvas,
    this.overlayStyle = AvTheme.lightOverlay,
    this.padTop = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> slivers;
  final List<Widget> actions;
  final Widget? leading;
  final Widget? bottomBar;
  final Color background;
  final SystemUiOverlayStyle overlayStyle;
  final bool padTop;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AvPageHeader(
                title: title,
                subtitle: subtitle,
                actions: actions,
                leading: leading,
              ),
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    if (padTop)
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AvSpace.xs),
                      ),
                    ...slivers,
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: MediaQuery.paddingOf(context).bottom +
                            AvSpace.xxl,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: bottomBar,
      ),
    );
  }
}

/// Header used at the top of every page.
class AvPageHeader extends StatelessWidget {
  const AvPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AvSpace.gutter,
        AvSpace.md,
        AvSpace.gutter,
        AvSpace.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AvSpace.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AvType.headingLarge.primary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AvType.bodySmall.muted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          for (final action in actions) ...[
            const SizedBox(width: AvSpace.xs),
            action,
          ],
        ],
      ),
    );
  }
}

/// Back button used on pushed routes.
class AvBackButton extends StatelessWidget {
  const AvBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AvIconButton(
      icon: Icons.arrow_back_rounded,
      tooltip: 'Back',
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}

/// Section heading with an optional trailing action.
class AvSectionHeader extends StatelessWidget {
  const AvSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.accent = AvColors.flare,
    this.padding = const EdgeInsets.fromLTRB(
      AvSpace.gutter,
      AvSpace.xl,
      AvSpace.gutter,
      AvSpace.sm,
    ),
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final Color accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AvType.headingMedium.primary),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: AvType.bodySmall.muted),
                    ],
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: AvSpace.sm),
          AvRule(accent: accent),
        ],
      ),
    );
  }
}

/// Uppercase label used above dense groups inside a card.
class AvOverline extends StatelessWidget {
  const AvOverline(this.text, {super.key, this.color = AvColors.textFaint});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: AvType.overline.copyWith(color: color));
  }
}

/// Standard horizontal page padding for slivers.
class AvGutter extends StatelessWidget {
  const AvGutter({super.key, required this.child, this.vertical = 0});

  final Widget child;
  final double vertical;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AvSpace.gutter,
        vertical: vertical,
      ),
      child: child,
    );
  }
}

/// Sliver wrapper that applies the page gutter.
class SliverGutter extends StatelessWidget {
  const SliverGutter({super.key, required this.child, this.top = 0, this.bottom = 0});

  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        AvSpace.gutter,
        top,
        AvSpace.gutter,
        bottom,
      ),
      sliver: SliverToBoxAdapter(child: child),
    );
  }
}

/// Row of label and value used inside detail cards.
class AvKeyValue extends StatelessWidget {
  const AvKeyValue({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
    this.valueColor,
    this.dense = false,
    this.onInk = false,
  });

  final String label;
  final String value;
  final Widget? trailing;
  final Color? valueColor;
  final bool dense;
  final bool onInk;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 5 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: AvType.bodySmall.copyWith(
                color: onInk ? AvColors.textOnInkMuted : AvColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: AvSpace.sm),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              textAlign: TextAlign.right,
              style: AvType.tabular(AvType.titleSmall).copyWith(
                color: valueColor ??
                    (onInk ? AvColors.textOnInk : AvColors.textPrimary),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AvSpace.xs),
            Flexible(child: trailing!),
          ],
        ],
      ),
    );
  }
}

/// Empty state used where a list has no content yet.
class AvEmptyState extends StatelessWidget {
  const AvEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.accent = AvColors.insight,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AvCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AvSpace.lg,
        vertical: AvSpace.xxl,
      ),
      child: Column(
        children: [
          AvGlyph(icon: icon, color: accent, size: 52),
          const SizedBox(height: AvSpace.md),
          Text(title, style: AvType.headingSmall.primary),
          const SizedBox(height: AvSpace.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AvType.bodySmall.muted,
          ),
          if (action != null) ...[
            const SizedBox(height: AvSpace.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Fixed action bar pinned under the page content.
class AvBottomBar extends StatelessWidget {
  const AvBottomBar({
    super.key,
    required this.children,
    this.note,
    this.color = AvColors.surface,
  });

  final List<Widget> children;

  /// Short line shown above the actions, used for validation or context.
  final Widget? note;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AvSpace.gutter,
        AvSpace.sm,
        AvSpace.gutter,
        MediaQuery.paddingOf(context).bottom + AvSpace.sm,
      ),
      decoration: BoxDecoration(
        color: color,
        border: const Border(top: BorderSide(color: AvColors.hairline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (note != null) ...[
            note!,
            const SizedBox(height: AvSpace.sm),
          ],
          Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: AvSpace.sm),
                children[i],
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Hairline separator used between rows inside a card.
class AvSeparator extends StatelessWidget {
  const AvSeparator({super.key, this.inset = 0, this.onInk = false});

  final double inset;
  final bool onInk;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: inset),
      child: Container(
        height: 1,
        color: onInk ? AvColors.hairlineOnInk : AvColors.hairline,
      ),
    );
  }
}

/// Two-column responsive grid used for metric tiles.
class AvTileGrid extends StatelessWidget {
  const AvTileGrid({
    super.key,
    required this.children,
    this.spacing = AvSpace.sm,
    this.minTileWidth = 152,
    this.aspectRatio = 1.42,
  });

  final List<Widget> children;
  final double spacing;
  final double minTileWidth;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    // Tiles hold a fixed amount of text, so their height has to follow the
    // reader's text size rather than the tile width alone.
    final textScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            (constraints.maxWidth / minTileWidth).floor().clamp(2, 4);
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(
                width: width,
                height: width / aspectRatio * textScale,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

/// Horizontal list that keeps consistent gutters and item spacing.
class AvCarousel extends StatelessWidget {
  const AvCarousel({
    super.key,
    required this.height,
    required this.children,
    this.spacing = AvSpace.sm,
  });

  final double height;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AvSpace.gutter),
        itemCount: children.length,
        separatorBuilder: (_, __) => SizedBox(width: spacing),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }
}
