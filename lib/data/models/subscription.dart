import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';

enum PlanTier {
  free,
  playerPro,
  coachPro,
  academy;

  String get label => switch (this) {
    PlanTier.free => 'Free',
    PlanTier.playerPro => 'Player Pro',
    PlanTier.coachPro => 'Coach Pro',
    PlanTier.academy => 'Team & Academy',
  };

  Color get accent => switch (this) {
    PlanTier.free => AvColors.court,
    PlanTier.playerPro => AvColors.flare,
    PlanTier.coachPro => AvColors.insight,
    PlanTier.academy => AvColors.made,
  };
}

enum BillingPeriod {
  monthly,
  annual;

  String get label => this == BillingPeriod.monthly ? 'Monthly' : 'Annual';
}

class PlanOption {
  const PlanOption({
    required this.tier,
    required this.tagline,
    required this.monthlyPrice,
    required this.annualPrice,
    required this.features,
    required this.limits,
    this.trialDays = 0,
    this.recommended = false,
  });

  final PlanTier tier;
  final String tagline;
  final double monthlyPrice;
  final double annualPrice;
  final List<String> features;
  final List<String> limits;
  final int trialDays;
  final bool recommended;

  double priceFor(BillingPeriod period) =>
      period == BillingPeriod.monthly ? monthlyPrice : annualPrice;

  /// Effective monthly cost when billed annually.
  double get annualMonthlyEquivalent => annualPrice / 12;

  int get annualSavingPercent {
    if (monthlyPrice <= 0) return 0;
    final full = monthlyPrice * 12;
    return (((full - annualPrice) / full) * 100).round();
  }
}

enum EntitlementState {
  active,
  trial,
  gracePeriod,
  expired;

  String get label => switch (this) {
    EntitlementState.active => 'Active',
    EntitlementState.trial => 'Trial',
    EntitlementState.gracePeriod => 'Billing retry',
    EntitlementState.expired => 'Expired',
  };

  Color get color => switch (this) {
    EntitlementState.active => AvColors.made,
    EntitlementState.trial => AvColors.court,
    EntitlementState.gracePeriod => AvColors.caution,
    EntitlementState.expired => AvColors.miss,
  };
}

class Entitlement {
  const Entitlement({
    required this.tier,
    required this.state,
    required this.period,
    required this.renewsAt,
    required this.store,
    required this.verifiedServerSide,
  });

  final PlanTier tier;
  final EntitlementState state;
  final BillingPeriod period;
  final DateTime renewsAt;
  final String store;
  final bool verifiedServerSide;
}
