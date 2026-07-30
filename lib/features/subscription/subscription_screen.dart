import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/subscription.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import '../../state/stores.dart';

/// Plans and entitlement. Prices, limits and what happens when a subscription
/// lapses are all stated on one screen; nothing about billing is implied.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  BillingPeriod _period = BillingPeriod.annual;
  PlanTier? _selected;

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(planOptionsProvider);
    final entitlement = ref.watch(entitlementProvider);
    final selected = _selected ?? entitlement.tier;

    return AvScaffold(
      title: 'Plans',
      subtitle: 'Your data stays yours on every plan',
      leading: const AvBackButton(),
      bottomBar: AvBottomBar(
        note: Text(
          'Billed through ${entitlement.store}. Cancel any time from your '
          'store account; access continues to the end of the paid period.',
          style: AvType.caption.faint,
        ),
        children: [
          Expanded(
            child: AvButton(
              label: selected == entitlement.tier
                  ? 'Manage this plan'
                  : 'Switch to ${selected.label}',
              variant: selected == entitlement.tier
                  ? AvButtonVariant.outline
                  : AvButtonVariant.primary,
              size: AvButtonSize.large,
              expand: true,
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    selected == entitlement.tier
                        ? 'Opening ${entitlement.store} to manage '
                              '${selected.label}'
                        : 'Opening ${entitlement.store} to confirm the '
                              'change to ${selected.label}',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      slivers: [
        SliverGutter(child: _EntitlementCard(entitlement: entitlement)),
        SliverGutter(
          top: AvSpace.md,
          child: AvSegmented<BillingPeriod>(
            values: BillingPeriod.values,
            labels: const ['Monthly', 'Annual'],
            selected: _period,
            onChanged: (value) => setState(() => _period = value),
          ),
        ),
        for (final plan in plans)
          SliverGutter(
            top: AvSpace.sm,
            child: _PlanCard(
              plan: plan,
              period: _period,
              current: plan.tier == entitlement.tier,
              selected: plan.tier == selected,
              onTap: () => setState(() => _selected = plan.tier),
            ),
          ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'What never changes',
            accent: AvColors.court,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              children: const [
                _GuaranteeRow(
                  icon: Icons.download_rounded,
                  title: 'Your data stays exportable',
                  detail:
                      'Sessions, measurements and clips can be exported '
                      'in full at any time, including after a plan lapses.',
                ),
                AvSeparator(inset: 34),
                _GuaranteeRow(
                  icon: Icons.lock_clock_rounded,
                  title: 'Recorded work is never deleted by billing',
                  detail:
                      'If a subscription ends, historical sessions stay '
                      'readable. Only new premium analysis stops.',
                ),
                AvSeparator(inset: 34),
                _GuaranteeRow(
                  icon: Icons.child_care_rounded,
                  title: 'Minor accounts are never upsold',
                  detail:
                      'Purchase flows are hidden on accounts under '
                      'sixteen and routed to the guardian instead.',
                ),
                AvSeparator(inset: 34),
                _GuaranteeRow(
                  icon: Icons.receipt_long_rounded,
                  title: 'No usage-based surprises',
                  detail:
                      'Cloud analysis credits are shown before each run '
                      'and never billed automatically.',
                ),
              ],
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.md,
          child: Row(
            children: [
              Expanded(
                child: AvButton(
                  label: 'Restore purchases',
                  variant: AvButtonVariant.outline,
                  size: AvButtonSize.small,
                  expand: true,
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Checking your store account'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AvSpace.xs),
              Expanded(
                child: AvButton(
                  label: 'Manage billing',
                  variant: AvButtonVariant.ghost,
                  size: AvButtonSize.small,
                  expand: true,
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Opening ${entitlement.store}')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EntitlementCard extends StatelessWidget {
  const _EntitlementCard({required this.entitlement});

  final Entitlement entitlement;

  @override
  Widget build(BuildContext context) {
    return AvInkCard(
      padding: const EdgeInsets.all(AvSpace.lg),
      accent: entitlement.tier.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AvSpace.sm,
            runSpacing: AvSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                'CURRENT PLAN',
                style: AvType.overline.copyWith(color: AvColors.textOnInkMuted),
              ),
              AvPill(
                label: entitlement.state.label,
                color: entitlement.state.color,
                filled: true,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AvSpace.sm),
          Text(
            entitlement.tier.label,
            style: AvType.displayMedium.copyWith(
              color: AvColors.textOnInk,
              fontSize: 30,
            ),
          ),
          const SizedBox(height: AvSpace.xs),
          Text(
            '${entitlement.period.label} \u00B7 renews '
            '${Fmt.fullDate(entitlement.renewsAt)}',
            style: AvType.bodySmall.copyWith(color: AvColors.textOnInkMuted),
          ),
          const SizedBox(height: AvSpace.md),
          Row(
            children: [
              Icon(
                entitlement.verifiedServerSide
                    ? Icons.verified_user_rounded
                    : Icons.gpp_maybe_rounded,
                size: 15,
                color: entitlement.verifiedServerSide
                    ? AvColors.made
                    : AvColors.caution,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entitlement.verifiedServerSide
                      ? 'Receipt verified with ${entitlement.store}.'
                      : 'Waiting on receipt verification from '
                            '${entitlement.store}.',
                  style: AvType.caption.copyWith(
                    color: AvColors.textOnInkMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.period,
    required this.current,
    required this.selected,
    required this.onTap,
  });

  final PlanOption plan;
  final BillingPeriod period;
  final bool current;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = plan.priceFor(period);

    return AvPressable(
      onTap: onTap,
      borderRadius: AvRadius.allLg,
      child: AnimatedContainer(
        duration: AvMotion.fast,
        padding: const EdgeInsets.all(AvSpace.md),
        decoration: BoxDecoration(
          color: AvColors.surface,
          borderRadius: AvRadius.allLg,
          border: Border.all(
            color: selected ? plan.tier.accent : AvColors.hairline,
            width: selected ? 1.8 : 1,
          ),
          boxShadow: selected ? AvShadow.level2 : AvShadow.level1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          plan.tier.label,
                          style: AvType.headingSmall.primary,
                        ),
                      ),
                      if (plan.recommended) ...[
                        const SizedBox(width: AvSpace.xs),
                        AvPill(
                          label: 'Most chosen',
                          color: plan.tier.accent,
                          dense: true,
                        ),
                      ],
                      if (current) ...[
                        const SizedBox(width: AvSpace.xxs),
                        const AvPill(
                          label: 'Current',
                          color: AvColors.made,
                          dense: true,
                        ),
                      ],
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: AvMotion.fast,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? plan.tier.accent : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? plan.tier.accent
                          : AvColors.hairlineStrong,
                      width: 1.6,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(plan.tagline, style: AvType.bodySmall.muted),
            const SizedBox(height: AvSpace.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          Fmt.money(price),
                          style: AvType.tabular(
                            AvType.metricLarge,
                          ).copyWith(fontSize: 28, color: plan.tier.accent),
                        ),
                        if (price > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            period == BillingPeriod.monthly
                                ? 'per month'
                                : 'per year',
                            style: AvType.caption.muted,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (period == BillingPeriod.annual &&
                    plan.annualSavingPercent > 0) ...[
                  const SizedBox(width: AvSpace.xs),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: AvPill(
                      label: 'Save ${plan.annualSavingPercent}%',
                      color: AvColors.made,
                      dense: true,
                    ),
                  ),
                ],
              ],
            ),
            if (period == BillingPeriod.annual && price > 0) ...[
              const SizedBox(height: 2),
              Text(
                '${Fmt.money(plan.annualMonthlyEquivalent)} per month, '
                'billed once a year',
                style: AvType.caption.faint,
              ),
            ],
            if (plan.trialDays > 0) ...[
              const SizedBox(height: AvSpace.xs),
              Text(
                '${plan.trialDays}-day trial, cancel before it ends and you '
                'are not charged.',
                style: AvType.caption.copyWith(color: AvColors.courtDeep),
              ),
            ],
            const SizedBox(height: AvSpace.md),
            for (final feature in plan.features)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: plan.tier.accent,
                    ),
                    const SizedBox(width: AvSpace.xs),
                    Expanded(
                      child: Text(feature, style: AvType.bodySmall.muted),
                    ),
                  ],
                ),
              ),
            if (plan.limits.isNotEmpty) ...[
              const SizedBox(height: AvSpace.xs),
              for (final limit in plan.limits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.remove_rounded,
                        size: 15,
                        color: AvColors.textFaint,
                      ),
                      const SizedBox(width: AvSpace.xs),
                      Expanded(
                        child: Text(limit, style: AvType.bodySmall.faint),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuaranteeRow extends StatelessWidget {
  const _GuaranteeRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AvSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AvColors.court),
          const SizedBox(width: AvSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AvType.titleSmall.primary),
                const SizedBox(height: 2),
                Text(detail, style: AvType.caption.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
