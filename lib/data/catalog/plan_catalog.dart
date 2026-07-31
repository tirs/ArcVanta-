import '../models/subscription.dart';

/// The published price list.
///
/// Constant on purpose, unlike anything describing the athlete: this is
/// product copy, not a measurement. It stays compiled in so the paywall
/// renders offline and cannot show a price the app is not prepared to charge.
abstract final class PlanCatalog {
  static const List<PlanOption> all = [
    PlanOption(
      tier: PlanTier.free,
      tagline: 'Count shots and check your setup at no cost.',
      monthlyPrice: 0,
      annualPrice: 0,
      features: [
        'Eight live sessions each month',
        'Makes, attempts and percentage',
        'Standard drill library',
        'On-device processing',
      ],
      limits: [
        'Thirty days of history',
        'No mechanics metrics',
        'No coach sharing',
      ],
    ),
    PlanOption(
      tier: PlanTier.playerPro,
      tagline: 'Full mechanics, trends and automatic highlights.',
      monthlyPrice: 14.99,
      annualPrice: 119.99,
      features: [
        'Unlimited supported sessions',
        'Complete mechanics and ball-flight metrics',
        'Shot charts, heatmaps and trend explanations',
        'Personalised training plans',
        'Full history and data export',
      ],
      limits: [],
      trialDays: 14,
      recommended: true,
    ),
    PlanOption(
      tier: PlanTier.coachPro,
      tagline: 'Roster, assignments and review workflow.',
      monthlyPrice: 39.99,
      annualPrice: 359.99,
      features: [
        'Everything in Player Pro',
        'Athlete roster up to 30 players',
        'Drill assignments with due dates',
        'Session review queue and annotations',
        'Athlete and team reports',
      ],
      limits: ['Thirty athletes per coach seat'],
      trialDays: 14,
    ),
    PlanOption(
      tier: PlanTier.academy,
      tagline: 'Multiple coaches, teams and central administration.',
      monthlyPrice: 149.99,
      annualPrice: 1439.99,
      features: [
        'Everything in Coach Pro',
        'Unlimited coaches and teams',
        'Organisation administration and branding',
        'Shared drill templates',
        'Team analytics with minimum-data protection',
        'Central billing and configurable retention',
      ],
      limits: [],
    ),
  ];

  static PlanOption forTier(PlanTier tier) =>
      all.firstWhere((option) => option.tier == tier);
}
