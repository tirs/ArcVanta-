import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../design/components/av_brand.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_brand_scaffold.dart';
import '../../design/components/av_surface.dart';
import '../../state/app_settings.dart';

enum _AuthMode { signIn, createAccount }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  _AuthMode _mode = _AuthMode.createAccount;
  bool _obscure = true;
  bool _busy = false;
  bool _acceptedTerms = false;

  bool get _isApplePlatform => !kIsWeb && Platform.isIOS;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_mode == _AuthMode.createAccount && !_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accept the terms and privacy notice to continue.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() => _busy = false);
    context.go(AppRoute.role);
  }

  void _continueAsGuest() {
    ref.read(appSettingsProvider.notifier).setGuestMode(true);
    context.go(AppRoute.role);
  }

  @override
  Widget build(BuildContext context) {
    final creating = _mode == _AuthMode.createAccount;

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
            Text(
              creating ? 'Create your account' : 'Welcome back',
              style: AvType.displayMedium.onInk,
            ),
            const SizedBox(height: AvSpace.xs),
            Text(
              creating
                  ? 'Your sessions sync across devices and stay private until you share them.'
                  : 'Sign in to reach your history, plans and coach workspace.',
              style: AvType.body.onInkMuted,
            ),
            const SizedBox(height: AvSpace.xl),
            if (_isApplePlatform) ...[
              _ProviderButton(
                label: 'Continue with Apple',
                icon: Icons.apple_rounded,
                background: AvColors.ink,
                foreground: Colors.white,
                onPressed: () => context.go(AppRoute.role),
              ),
              const SizedBox(height: AvSpace.sm),
            ],
            _ProviderButton(
              label: 'Continue with Google',
              icon: Icons.g_mobiledata_rounded,
              background: AvColors.surface,
              foreground: AvColors.textPrimary,
              onPressed: () => context.go(AppRoute.role),
            ),
            const SizedBox(height: AvSpace.lg),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AvSpace.sm),
                  child: Text('or use email', style: AvType.caption.onInkMuted),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: AvSpace.lg),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Enter your email address.';
                      if (!RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+',
                      ).hasMatch(text)) {
                        return 'That does not look like an email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AvSpace.sm),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                      ),
                    ),
                    validator: (value) {
                      final text = value ?? '';
                      if (text.isEmpty) return 'Enter your password.';
                      if (creating && text.length < 10) {
                        return 'Use at least 10 characters.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            if (creating) ...[
              const SizedBox(height: AvSpace.sm),
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
                            'I accept the terms of service and the privacy notice. '
                            'Cloud backup and model-training consent are separate '
                            'choices in settings.',
                            style: AvType.bodySmall.onInkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: AvSpace.xs),
              Align(
                alignment: Alignment.centerRight,
                child: AvTextAction(
                  label: 'Reset password',
                  icon: null,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _email.text.trim().isEmpty
                              ? 'Enter your email address first.'
                              : 'Reset link sent to ${_email.text.trim()}.',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: AvSpace.lg),
            AvButton(
              label: creating ? 'Create account' : 'Sign in',
              onPressed: _submit,
              busy: _busy,
              size: AvButtonSize.large,
              expand: true,
            ),
            const SizedBox(height: AvSpace.sm),
            Center(
              child: AvTextAction(
                label: creating
                    ? 'I already have an account'
                    : 'Create a new account',
                icon: null,
                color: AvColors.insightOnInk,
                onPressed: () => setState(
                  () => _mode = creating
                      ? _AuthMode.signIn
                      : _AuthMode.createAccount,
                ),
              ),
            ),
            const SizedBox(height: AvSpace.xl),
            AvInkCard(
              raised: true,
              accent: AvColors.court,
              padding: const EdgeInsets.all(AvSpace.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AvGlyph(
                    icon: Icons.wifi_off_rounded,
                    color: AvColors.court,
                    size: 36,
                  ),
                  const SizedBox(width: AvSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Train without an account',
                          style: AvType.titleMedium.onInk,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Guest mode keeps every session on this device. '
                          'You can attach an account later without losing data.',
                          style: AvType.bodySmall.onInkMuted,
                        ),
                        const SizedBox(height: AvSpace.sm),
                        AvButton(
                          label: 'Continue as guest',
                          variant: AvButtonVariant.outline,
                          size: AvButtonSize.small,
                          onInk: true,
                          onPressed: _continueAsGuest,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AvPressable(
      onTap: onPressed,
      borderRadius: AvRadius.pill,
      semanticLabel: label,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: AvRadius.pill,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: foreground),
            const SizedBox(width: AvSpace.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AvType.titleMedium.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
