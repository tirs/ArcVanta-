import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog/plan_catalog.dart';
import '../data/models/subscription.dart';

/// What the user is entitled to.
///
/// This build ships without a billing integration, so there is exactly one
/// truthful answer: the free tier, unverified, with no renewal date. The
/// previous version of this file returned an active annual Player Pro
/// subscription "verified server side", which was a fabrication — there is no
/// server and there was no purchase.
///
/// When receipts land, this becomes a real check against the store and
/// [BillingAvailability.isAvailable] flips. Until then the paywall shows the
/// price list and says plainly that purchasing is not live.
final entitlementProvider = Provider<Entitlement>((ref) {
  return Entitlement(
    tier: PlanTier.free,
    state: EntitlementState.active,
    period: BillingPeriod.monthly,
    // The free tier does not renew. Screens read `tier == free` before
    // showing a date, so this value is never presented to the user.
    renewsAt: DateTime.fromMillisecondsSinceEpoch(0),
    store: 'Not purchased',
    verifiedServerSide: false,
  );
});

final planOptionsProvider = Provider<List<PlanOption>>(
  (ref) => PlanCatalog.all,
);

/// Whether in-app purchase is wired up on this build.
abstract final class BillingAvailability {
  static const bool isAvailable = false;

  static const String unavailableReason =
      'Purchasing is not enabled in this build. Every measurement feature '
      'runs on your device at no cost.';
}
