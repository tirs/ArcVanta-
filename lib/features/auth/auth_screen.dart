import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../design/components/av_brand.dart';
import '../../design/components/av_brand_scaffold.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_surface.dart';
import '../../state/app_settings.dart';

/// The entry point into the app.
///
/// There is deliberately no sign-in form here. Every measurement ArcVanta
/// makes happens on the phone, and this build ships without the server that
/// accounts, sync and coach sharing would need. A password box that accepted
/// anything and a "sessions sync across devices" promise nothing honours would
/// both be lies, and the second one is the kind users act on.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _acceptedTerms = false;

  void _start() {
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accept the terms and privacy notice to continue.'),
        ),
      );
      return;
    }
    ref.read(appSettingsProvider.notifier).setGuestMode(true);
    context.go(AppRoute.role);
  }

  @override
  Widget build(BuildContext context) {
    return AvBrandScaffold(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AvSpace.gutter,
          AvSpace.lg,
          AvSpace.gutter,
          AvSpace.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AvBrandLockup(markSize: 40, fontSize: 19, onInk: true),
            const SizedBox(height: AvSpace.xxl),
            Text('Set up on this device', style: AvType.displayMedium.onInk),
            const SizedBox(height: AvSpace.xs),
            Text(
              'ArcVanta measures your shooting on the phone itself. There is '
              'no account to create and nothing to upload.',
              style: AvType.body.onInkMuted,
            ),
            const SizedBox(height: AvSpace.xl),
            const _PointCard(
              icon: Icons.videocam_outlined,
              accent: AvColors.court,
              title: 'The camera does the counting',
              body:
                  'Place the phone so it can see the ring. It finds you, the '
                  'ball and the rim, then records every attempt while you '
                  'keep shooting.',
            ),
            const SizedBox(height: AvSpace.sm),
            const _PointCard(
              icon: Icons.phonelink_lock_outlined,
              accent: AvColors.insight,
              title: 'Nothing leaves the phone',
              body:
                  'Frames are measured and discarded as they arrive. Only the '
                  'numbers are written here, and no server sees them.',
            ),
            const SizedBox(height: AvSpace.sm),
            const _PointCard(
              icon: Icons.groups_outlined,
              accent: AvColors.insightOnInk,
              title: 'Coach sharing comes later',
              body:
                  'Rosters, assignments and review need an account service '
                  'this build does not include. Everything recorded here '
                  'carries over when it arrives.',
            ),
            const SizedBox(height: AvSpace.lg),
            InkWell(
              borderRadius: AvRadius.allSm,
              onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _acceptedTerms,
                      onChanged: (value) =>
                          setState(() => _acceptedTerms = value ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 11),
                        child: Text(
                          'I accept the terms of service and the privacy '
                          'notice. Recording, storage and deletion are all '
                          'controlled from settings.',
                          style: AvType.bodySmall.onInkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Agreeing to a document nobody can open is not agreement, so both
            // are one tap away from the box that accepts them.
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AvSpace.sm,
                children: [
                  _DocumentLink(
                    label: 'Read the terms',
                    onTap: () => context.push(AppRoute.terms),
                  ),
                  _DocumentLink(
                    label: 'Read the privacy notice',
                    onTap: () => context.push(AppRoute.privacyPolicy),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AvSpace.lg),
            AvButton(
              label: 'Start training',
              icon: Icons.arrow_forward_rounded,
              onPressed: _start,
              size: AvButtonSize.large,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PointCard extends StatelessWidget {
  const _PointCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AvInkCard(
      raised: true,
      accent: accent,
      padding: const EdgeInsets.all(AvSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvGlyph(icon: icon, color: accent, size: 36),
          const SizedBox(width: AvSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AvType.titleMedium.onInk),
                const SizedBox(height: 3),
                Text(body, style: AvType.bodySmall.onInkMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Underlined link sized for the ink entry flow.
class _DocumentLink extends StatelessWidget {
  const _DocumentLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AvSpace.xs),
        child: Text(
          label,
          style: AvType.caption.copyWith(
            color: AvColors.insightOnInk,
            decoration: TextDecoration.underline,
            decorationColor: AvColors.insightOnInk,
          ),
        ),
      ),
    );
  }
}
