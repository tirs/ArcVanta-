import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../design/components/av_brand_scaffold.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import '../../state/app_settings.dart';

class GuardianConsentScreen extends ConsumerStatefulWidget {
  const GuardianConsentScreen({super.key});

  @override
  ConsumerState<GuardianConsentScreen> createState() =>
      _GuardianConsentScreenState();
}

class _GuardianConsentScreenState extends ConsumerState<GuardianConsentScreen> {
  final _guardianName = TextEditingController();
  final _guardianEmail = TextEditingController();

  final _permissions = <_Permission>[
    const _Permission(
      key: 'camera',
      title: 'Camera and microphone during sessions',
      detail:
          'Required for shot detection. Frames are processed on the device and '
          'are not stored unless a clip is saved.',
      required: true,
      granted: true,
    ),
    const _Permission(
      key: 'local',
      title: 'Store sessions on this device',
      detail: 'Results, clips and settings stay in encrypted local storage.',
      required: true,
      granted: true,
    ),
    const _Permission(
      key: 'coach',
      title: 'Allow a named coach to see results',
      detail:
          'The guardian approves each coach individually and can revoke access '
          'at any time.',
      granted: true,
    ),
    const _Permission(
      key: 'cloud',
      title: 'Encrypted cloud backup and sync',
      detail:
          'Enables history across devices. Source video expires on the schedule '
          'set in privacy controls.',
      granted: false,
    ),
    const _Permission(
      key: 'training',
      title: 'Contribute anonymised video to model training',
      detail:
          'Separate from service use. Faces are blurred, identifiers removed, '
          'and consent can be withdrawn with deletion propagation.',
      granted: false,
    ),
    const _Permission(
      key: 'analytics',
      title: 'Product and reliability analytics',
      detail:
          'Device tier, model version and confidence distributions. Never raw '
          'video.',
      granted: true,
    ),
  ];

  @override
  void dispose() {
    _guardianName.dispose();
    _guardianEmail.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      _guardianName.text.trim().length > 1 && _guardianEmail.text.contains('@');

  @override
  Widget build(BuildContext context) {
    return AvBrandScaffold(
      child: Column(
        children: [
          AvPageHeader(
            onInk: true,
            title: 'Guardian consent',
            subtitle: 'Required before a minor account can share anything.',
            leading: AvBackButton(
              onInk: true,
              onPressed: () => context.go(AppRoute.playerSetup),
            ),
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AvSpace.gutter,
                AvSpace.xs,
                AvSpace.gutter,
                AvSpace.md,
              ),
              children: [
                AvInkCard(
                  raised: true,
                  accent: AvColors.court,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const AvGlyph(
                            icon: Icons.shield_rounded,
                            color: AvColors.court,
                            size: 40,
                          ),
                          const SizedBox(width: AvSpace.sm),
                          Expanded(
                            child: Text(
                              'Private until a guardian says otherwise',
                              style: AvType.headingSmall.onInk,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AvSpace.sm),
                      Text(
                        'No public profile, no open messaging, no precise court '
                        'location and no leaderboards outside an approved team. '
                        'These defaults do not change with a subscription.',
                        style: AvType.bodySmall.onInkMuted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AvSpace.md),
                AvInkCard(
                  raised: true,
                  child: Column(
                    children: [
                      TextField(
                        controller: _guardianName,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Guardian full name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: AvSpace.sm),
                      TextField(
                        controller: _guardianEmail,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Guardian email address',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                          helperText:
                              'A verification message is sent to this address.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AvSpace.md),
                Text('Permissions', style: AvType.headingSmall.onInk),
                const SizedBox(height: AvSpace.xs),
                Text(
                  'Each item is a separate decision and can be changed later '
                  'in privacy controls.',
                  style: AvType.bodySmall.onInkMuted,
                ),
                const SizedBox(height: AvSpace.sm),
                AvInkCard(
                  raised: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AvSpace.md,
                    vertical: AvSpace.xs,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _permissions.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _PermissionRow(
                          permission: _permissions[i],
                          onChanged: (value) => setState(
                            () => _permissions[i] = _permissions[i].copyWith(
                              granted: value,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AvSpace.md),
                AvInkCard(
                  child: Text(
                    'ArcVanta AI does not provide medical, rehabilitation or '
                    'injury diagnosis. Coaching feedback describes measured '
                    'movement only. Applicable youth privacy law in your market '
                    'may require additional verification steps before some '
                    'features are enabled.',
                    style: AvType.caption.onInkMuted,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AvSpace.gutter,
              AvSpace.sm,
              AvSpace.gutter,
              AvSpace.lg,
            ),
            child: AvButton(
              label: 'Record consent and finish',
              size: AvButtonSize.large,
              expand: true,
              onPressed: _canContinue
                  ? () {
                      ref
                          .read(appSettingsProvider.notifier)
                          .completeOnboarding();
                      context.go(AppRoute.home);
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Permission {
  const _Permission({
    required this.key,
    required this.title,
    required this.detail,
    required this.granted,
    this.required = false,
  });

  final String key;
  final String title;
  final String detail;
  final bool granted;
  final bool required;

  _Permission copyWith({bool? granted}) => _Permission(
    key: key,
    title: title,
    detail: detail,
    granted: granted ?? this.granted,
    required: required,
  );
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.permission, required this.onChanged});

  final _Permission permission;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AvSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        permission.title,
                        style: AvType.titleSmall.onInk,
                      ),
                    ),
                    if (permission.required) ...[
                      const SizedBox(width: 6),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AvColors.court.withValues(alpha: 0.22),
                          borderRadius: AvRadius.pill,
                        ),
                        child: Text(
                          'REQUIRED',
                          style: AvType.overline.copyWith(
                            color: AvColors.court,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(permission.detail, style: AvType.caption.onInkMuted),
              ],
            ),
          ),
          const SizedBox(width: AvSpace.sm),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Switch(
              value: permission.granted,
              onChanged: permission.required ? null : onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
