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
import '../../state/stores.dart';

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
      title: 'Camera during sessions',
      detail:
          'Required for shot detection. Frames are measured on the device and '
          'discarded. No video or audio is recorded.',
      required: true,
      granted: true,
    ),
    const _Permission(
      key: 'local',
      title: 'Store sessions on this device',
      detail:
          'Measurements and settings are held in the app\'s private storage '
          'on this phone. Deleting the app deletes them.',
      required: true,
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

  /// Attaches the guardian to the athlete's profile before finishing.
  ///
  /// The name entered here is the record of who approved the account, so it
  /// belongs on the profile rather than in a form that closes.
  Future<void> _recordConsent() async {
    final profile = ref.read(profileStoreProvider);
    if (profile != null) {
      await ref
          .read(profileStoreProvider.notifier)
          .save(
            profile.copyWith(
              guardianName: _guardianName.text.trim(),
              guardianEmail: _guardianEmail.text.trim(),
            ),
          );
    }

    if (!mounted) return;
    ref.read(appSettingsProvider.notifier).completeOnboarding();
    context.go(AppRoute.home);
  }

  @override
  Widget build(BuildContext context) {
    return AvBrandScaffold(
      child: Column(
        children: [
          AvPageHeader(
            onInk: true,
            title: 'Guardian consent',
            subtitle: 'Who is responsible for this account.',
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
                          helperMaxLines: 2,
                          helperText:
                              'Kept on this device as the record of who '
                              'approved the account.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AvSpace.md),
                Text('Permissions', style: AvType.headingSmall.onInk),
                const SizedBox(height: AvSpace.xs),
                Text(
                  'This build records and measures on the phone only, so '
                  'these two are the whole list. Coach sharing and backup '
                  'ask separately, if they are ever switched on.',
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
              onPressed: _canContinue ? _recordConsent : null,
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
