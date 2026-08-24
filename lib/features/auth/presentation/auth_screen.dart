import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/data/supabase/auth_repository.dart';
import '../../../core/data/supabase/supabase_config.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Modern, unified Auth Screen for Crux.
///
/// Starts with a sleek social-first landing ("Sign in with Google" / "Continue with Email"),
/// and seamlessly transitions to the rich email Log In / Sign Up form on demand.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _showEmailForm = false;
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _busy = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade800 : Colors.teal.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isError ? 6 : 8),
      ),
    );
  }

  Future<void> _runAuth(Future<String?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await action();
      if (message != null && mounted) {
        final looksLikeInfo =
            message.toLowerCase().contains('check your email') ||
                message.toLowerCase().contains('account created');
        _showMessage(message, isError: !looksLikeInfo);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    await _runAuth(() {
      if (_isLogin) {
        return ref.read(authProvider.notifier).login(email, password);
      }
      return ref.read(authProvider.notifier).signup(name, email, password);
    });
  }

  Future<void> _signInWithGoogle() async {
    await _runAuth(() => ref.read(authProvider.notifier).signInWithGoogle());
  }

  Future<void> _signInWithApple() async {
    await _runAuth(() => ref.read(authProvider.notifier).signInWithApple());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final platform = Theme.of(context).platform;
    final isIOS = platform == TargetPlatform.iOS;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Apple sign-in is only shown on iOS/macOS per Apple Guidelines
    final showApple = !kIsWeb &&
        (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS);

    final providers = ref.watch(authProvidersProvider);
    final showGoogle = providers.maybeWhen(
      data: (p) => p.google,
      orElse: () => true,
    );

    return Scaffold(
      backgroundColor: c.canvas,
      body: Stack(
        children: [
          // Ambient warm glow aura at top
          Positioned(
            top: -120,
            left: 0,
            right: 0,
            height: 380,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.9,
                    colors: [
                      c.ember.withValues(alpha: isDark ? 0.18 : 0.10),
                      c.ultraviolet.withValues(alpha: isDark ? 0.08 : 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: CxSpace.lg,
                  vertical: CxSpace.xl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Offline badge if Supabase not configured
                      if (!SupabaseConfig.isConfigured) ...[
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: CxSpace.md),
                            padding: const EdgeInsets.symmetric(
                              horizontal: CxSpace.md,
                              vertical: CxSpace.xs,
                            ),
                            decoration: BoxDecoration(
                              color: c.surfaceHigh,
                              borderRadius: CxRadii.brPill,
                              border: Border.all(
                                  color: c.warning.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_off_rounded,
                                    size: 14, color: c.warning),
                                const SizedBox(width: CxSpace.xs),
                                Text(
                                  'Offline Demo Mode',
                                  style: CxType.caption.copyWith(
                                    color: c.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Hero Header with Mascot
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Circular backdrop glow
                            Container(
                              width: 116,
                              height: 116,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c.surfaceHigh.withValues(alpha: 0.6),
                                border: Border.all(
                                  color: c.ember.withValues(alpha: 0.2),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: c.ember.withValues(
                                        alpha: isDark ? 0.2 : 0.08),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                            ),
                            YorhartWidget(
                              expression: _showEmailForm
                                  ? (_isLogin ? 'determined' : 'celebrating')
                                  : 'happy',
                              size: 104,
                              animate: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: CxSpace.md),

                      // Brand Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'CRUX',
                            style: CxType.headline.copyWith(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: CxSpace.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: c.ember.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'STRENGTH',
                              style: CxType.caption.copyWith(
                                color: c.ember,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: CxSpace.xs),

                      // Subtitle
                      AnimatedSwitcher(
                        duration: CxDuration.base,
                        child: Text(
                          !_showEmailForm
                              ? 'Your strength journey starts here.'
                              : (_isLogin
                                  ? 'Welcome back! Sign in to crush today\'s session.'
                                  : 'Create your account to start building permanent strength.'),
                          key: ValueKey<String>(
                              '${_showEmailForm}_$_isLogin'),
                          textAlign: TextAlign.center,
                          style: CxType.bodySmall.copyWith(
                            color: c.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: CxSpace.xl),

                      // Main Elevated Card Container
                      Container(
                        padding: const EdgeInsets.all(CxSpace.xl),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: c.border.withValues(alpha: 0.7),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.35 : 0.06),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: AnimatedSize(
                          duration: CxDuration.base,
                          curve: CxCurves.emphasized,
                          child: AnimatedCrossFade(
                            crossFadeState: _showEmailForm
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration: CxDuration.base,
                            firstChild: _buildSocialFirstView(
                              c: c,
                              isIOS: isIOS,
                              showApple: showApple,
                              showGoogle: showGoogle,
                            ),
                            secondChild: _buildEmailFormView(
                              c: c,
                              isDark: isDark,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: CxSpace.xl),

                      // Terms & Privacy
                      const _LegalConsentLine(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.25),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Initial Landing view: Shows Google & Apple sign-in and Continue with Email
  Widget _buildSocialFirstView({
    required CxColorsExt c,
    required bool isIOS,
    required bool showApple,
    required bool showGoogle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Apple first on iOS per Apple guidelines
        if (isIOS) ...[
          if (showApple) ...[
            _AppleSignInButton(
              busy: _busy,
              onTap: _signInWithApple,
            ),
            if (showGoogle) const SizedBox(height: CxSpace.md),
          ],
          if (showGoogle) ...[
            _GoogleSignInButton(
              busy: _busy,
              onTap: _signInWithGoogle,
            ),
            const SizedBox(height: CxSpace.md),
          ],
        ] else ...[
          if (showGoogle) ...[
            _GoogleSignInButton(
              busy: _busy,
              onTap: _signInWithGoogle,
            ),
            if (showApple) const SizedBox(height: CxSpace.md),
          ],
          if (showApple) ...[
            _AppleSignInButton(
              busy: _busy,
              onTap: _signInWithApple,
            ),
            const SizedBox(height: CxSpace.md),
          ],
        ],

        // Divider if social providers exist
        if (showGoogle || showApple) ...[
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: c.border.withValues(alpha: 0.6),
                  thickness: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: CxSpace.md),
                child: Text(
                  'OR',
                  style: CxType.caption.copyWith(
                    color: c.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: c.border.withValues(alpha: 0.6),
                  thickness: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: CxSpace.md),
        ],

        // Continue with Email button
        GestureDetector(
          onTap: _busy
              ? null
              : () {
                  CxHaptics.fire(CxHaptic.selection);
                  setState(() => _showEmailForm = true);
                },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: c.surfaceHigh.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline_rounded,
                    size: 19, color: c.textPrimary),
                const SizedBox(width: CxSpace.sm),
                Text(
                  'Continue with Email',
                  style: CxType.titleSmall.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Second View: Rich Email Form with Tab Switcher
  Widget _buildEmailFormView({
    required CxColorsExt c,
    required bool isDark,
  }) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Back button to social options
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _busy
                  ? null
                  : () {
                      CxHaptics.fire(CxHaptic.selection);
                      setState(() => _showEmailForm = false);
                    },
              child: Padding(
                padding: const EdgeInsets.only(bottom: CxSpace.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios_new_rounded,
                        size: 13, color: c.ember),
                    const SizedBox(width: 6),
                    Text(
                      'All sign-in options',
                      style: CxType.label.copyWith(
                        color: c.ember,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Segmented Switcher (Log In / Sign Up)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: c.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: c.border.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _AuthTabPill(
                    title: 'Log In',
                    icon: Icons.login_rounded,
                    selected: _isLogin,
                    onTap: () {
                      if (!_isLogin && !_busy) {
                        CxHaptics.fire(CxHaptic.selection);
                        setState(() => _isLogin = true);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _AuthTabPill(
                    title: 'Sign Up',
                    icon: Icons.person_add_outlined,
                    selected: !_isLogin,
                    onTap: () {
                      if (_isLogin && !_busy) {
                        CxHaptics.fire(CxHaptic.selection);
                        setState(() => _isLogin = false);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CxSpace.xl),

          // Full Name (only in Sign Up mode)
          AnimatedSize(
            duration: CxDuration.base,
            curve: CxCurves.emphasized,
            child: !_isLogin
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel(label: 'Full Name'),
                      const SizedBox(height: 6),
                      _AuthTextFormField(
                        controller: _nameController,
                        enabled: !_busy,
                        hintText: 'E.g. Alexander',
                        prefixIcon: Icons.badge_outlined,
                        textCapitalization: TextCapitalization.words,
                        validator: (val) {
                          if (!_isLogin &&
                              (val == null || val.trim().isEmpty)) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: CxSpace.md),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          // Email Address
          _FieldLabel(label: 'Email Address'),
          const SizedBox(height: 6),
          _AuthTextFormField(
            controller: _emailController,
            enabled: !_busy,
            hintText: 'you@example.com',
            prefixIcon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!val.contains('@') || !val.contains('.')) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: CxSpace.md),

          // Password
          _FieldLabel(label: 'Password'),
          const SizedBox(height: 6),
          _AuthTextFormField(
            controller: _passwordController,
            enabled: !_busy,
            hintText: '••••••••',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.password],
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
                color: c.textSecondary,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Please enter your password';
              }
              if (val.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: CxSpace.xl),

          // Submit Button
          CxButton(
            label: _isLogin ? 'Sign In' : 'Create Account',
            icon: _isLogin
                ? Icons.arrow_forward_rounded
                : Icons.check_circle_outline_rounded,
            loading: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}

/// Styled segmented tab button for Log In / Sign Up
class _AuthTabPill extends StatelessWidget {
  const _AuthTabPill({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? c.ember : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: c.ember.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? c.onEmber : c.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: CxType.titleSmall.copyWith(
                color: selected ? c.onEmber : c.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Field label with consistent typography
class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return Text(
      label,
      style: CxType.label.copyWith(
        color: c.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
    );
  }
}

/// Refined TextFormField with leading icon and modern borders
class _AuthTextFormField extends StatelessWidget {
  const _AuthTextFormField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      validator: validator,
      style: CxType.body.copyWith(
        color: c.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: CxType.body.copyWith(
          color: c.textTertiary.withValues(alpha: 0.8),
        ),
        filled: true,
        fillColor: c.surfaceHigh.withValues(alpha: 0.7),
        prefixIcon: Icon(prefixIcon, size: 19, color: c.textSecondary),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CxSpace.md,
          vertical: CxSpace.md,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: c.border.withValues(alpha: 0.8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: c.ember,
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: c.danger,
            width: 1.2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: c.danger,
            width: 1.8,
          ),
        ),
      ),
    );
  }
}

/// Official Google Sign-In button with exact Google brand vector icon
class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({
    required this.busy,
    required this.onTap,
  });

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: busy ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? c.surfaceHigh : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? c.border : c.border.withValues(alpha: 0.9),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _OfficialGoogleGLogo(size: 20),
              const SizedBox(width: CxSpace.md),
              Text(
                'Sign in with Google',
                style: CxType.titleSmall.copyWith(
                  color: isDark ? c.textPrimary : const Color(0xFF1F1F1F),
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modern Apple Sign-In button
class _AppleSignInButton extends StatelessWidget {
  const _AppleSignInButton({
    required this.busy,
    required this.onTap,
  });

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: busy ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? Colors.white : Colors.black,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.apple_rounded,
                size: 22,
                color: isDark ? Colors.black : Colors.white,
              ),
              const SizedBox(width: CxSpace.md),
              Text(
                'Sign in with Apple',
                style: CxType.titleSmall.copyWith(
                  color: isDark ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pixel-perfect Official Google Brand "G" Vector Icon
/// Exact official Google brand colors and bezier paths
class _OfficialGoogleGLogo extends StatelessWidget {
  const _OfficialGoogleGLogo({this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OfficialGoogleGPainter(),
      ),
    );
  }
}

class _OfficialGoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Official Google 48x48 vector coordinate space
    final scale = size.width / 48.0;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    // 1. Blue segment (#4285F4)
    paint.color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(46.98, 24.55)
      ..cubicTo(46.98, 22.98, 46.83, 21.46, 46.6, 20.0)
      ..lineTo(24.0, 20.0)
      ..lineTo(24.0, 29.02)
      ..lineTo(36.94, 29.02)
      ..cubicTo(36.36, 31.98, 34.68, 34.5, 32.16, 36.19)
      ..lineTo(39.89, 42.19)
      ..cubicTo(44.4, 38.01, 46.98, 31.83, 46.98, 24.55)
      ..close();
    canvas.drawPath(bluePath, paint);

    // 2. Green segment (#34A853)
    paint.color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(24.0, 48.0)
      ..cubicTo(30.48, 48.0, 35.93, 45.87, 39.89, 42.19)
      ..lineTo(32.16, 36.19)
      ..cubicTo(30.01, 37.64, 27.24, 38.5, 24.0, 38.5)
      ..cubicTo(17.74, 38.5, 12.43, 34.28, 10.53, 28.59)
      ..lineTo(2.55, 34.79)
      ..cubicTo(6.51, 42.62, 14.62, 48.0, 24.0, 48.0)
      ..close();
    canvas.drawPath(greenPath, paint);

    // 3. Yellow segment (#FBBC05)
    paint.color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..moveTo(10.53, 28.59)
      ..cubicTo(10.05, 27.14, 9.77, 25.6, 9.77, 24.0)
      ..cubicTo(9.77, 22.4, 10.05, 20.86, 10.53, 19.41)
      ..lineTo(2.55, 13.22)
      ..cubicTo(0.92, 16.46, 0.0, 20.12, 0.0, 24.0)
      ..cubicTo(0.0, 27.88, 0.92, 31.54, 2.55, 34.79)
      ..lineTo(10.53, 28.59)
      ..close();
    canvas.drawPath(yellowPath, paint);

    // 4. Red segment (#EA4335)
    paint.color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(24.0, 9.5)
      ..cubicTo(27.54, 9.5, 30.71, 10.72, 33.21, 13.1)
      ..lineTo(40.06, 6.25)
      ..cubicTo(35.9, 2.38, 30.47, 0.0, 24.0, 0.0)
      ..cubicTo(14.62, 0.0, 6.51, 5.38, 2.56, 13.22)
      ..lineTo(10.54, 19.41)
      ..cubicTo(12.43, 13.72, 17.74, 9.5, 24.0, 9.5)
      ..close();
    canvas.drawPath(redPath, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// "By continuing you agree to…" with tappable in-app document links.
class _LegalConsentLine extends StatelessWidget {
  const _LegalConsentLine();

  @override
  Widget build(BuildContext context) {
    final c = context.cx;
    final base = CxType.caption.copyWith(
      color: c.textTertiary,
      height: 1.45,
      fontSize: 11.5,
    );
    final link = base.copyWith(
      color: c.textSecondary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: c.textSecondary.withValues(alpha: 0.5),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CxSpace.sm),
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            const TextSpan(text: 'By continuing you agree to Crux\'s\n'),
            TextSpan(
              text: 'Terms of Use',
              style: link,
              recognizer: TapGestureRecognizer()
                ..onTap = () => context.push(Routes.terms),
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: link,
              recognizer: TapGestureRecognizer()
                ..onTap = () => context.push(Routes.privacy),
            ),
            const TextSpan(text: '.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

