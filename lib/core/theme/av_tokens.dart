import 'package:flutter/widgets.dart';

import 'av_colors.dart';

/// Spacing scale. Every gap in the product resolves to one of these steps.
abstract final class AvSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 44;

  /// Horizontal page gutter.
  static const double gutter = 20;
}

abstract final class AvRadius {
  static const Radius xs = Radius.circular(8);
  static const Radius sm = Radius.circular(12);
  static const Radius md = Radius.circular(18);
  static const Radius lg = Radius.circular(24);
  static const Radius xl = Radius.circular(32);

  static const BorderRadius allXs = BorderRadius.all(xs);
  static const BorderRadius allSm = BorderRadius.all(sm);
  static const BorderRadius allMd = BorderRadius.all(md);
  static const BorderRadius allLg = BorderRadius.all(lg);
  static const BorderRadius allXl = BorderRadius.all(xl);
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

/// Warm, low-contrast elevation. Shadows are tinted toward the canvas so cards
/// feel lit rather than cut out.
abstract final class AvShadow {
  static const List<BoxShadow> level1 = [
    BoxShadow(color: Color(0x0D2B2416), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A2B2416), blurRadius: 10, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> level2 = [
    BoxShadow(color: Color(0x0F2B2416), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(
      color: Color(0x142B2416),
      blurRadius: 24,
      offset: Offset(0, 10),
      spreadRadius: -6,
    ),
  ];

  static const List<BoxShadow> level3 = [
    BoxShadow(
      color: Color(0x1A2B2416),
      blurRadius: 40,
      offset: Offset(0, 18),
      spreadRadius: -10,
    ),
  ];

  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.28),
      blurRadius: 22,
      offset: const Offset(0, 10),
      spreadRadius: -8,
    ),
  ];

  static const List<BoxShadow> onInk = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 28,
      offset: Offset(0, 14),
      spreadRadius: -12,
    ),
  ];
}

abstract final class AvBorders {
  static const BorderSide hairline = BorderSide(
    color: AvColors.hairline,
    width: 1,
  );
  static const BorderSide hairlineStrong = BorderSide(
    color: AvColors.hairlineStrong,
    width: 1,
  );
  static const BorderSide onInk = BorderSide(
    color: AvColors.hairlineOnInk,
    width: 1,
  );

  static Border all(Color color, [double width = 1]) =>
      Border.all(color: color, width: width);
}

abstract final class AvMotion {
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 340);
  static const Duration deliberate = Duration(milliseconds: 560);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
}

/// Signature gradients. Used sparingly: hero panels, primary actions and the
/// live scoreboard.
abstract final class AvGradients {
  static const LinearGradient ink = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF232647), Color(0xFF15162B)],
  );

  static const LinearGradient flare = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF7A3D), Color(0xFFF23F13)],
  );

  static const LinearGradient insight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8168FF), Color(0xFF5734D8)],
  );

  static const LinearGradient court = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF19BCD4), Color(0xFF00849B)],
  );

  static const LinearGradient made = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF20B67F), Color(0xFF07724E)],
  );

  static const LinearGradient dawn = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF7EF), Color(0xFFF5F2EB)],
  );
}
