import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../shared/splash_router.dart';

/// Rafd-style login screen: full-bleed institutional-building photo
/// background with a dark scrim, a floating pale "ice-blue" login card,
/// and (on wide/web screens) a right-hand tagline block — mirroring the
/// user-provided reference design ("رفد").
///
/// LAYOUT NOTE (explicit user requirement): the card is placed on the
/// **left** side of the screen, specifically because the source photo
/// (`assets/images/login_bg.jpg`) has a parked car visible in its
/// lower-left region — placing the card there hides it. This is the
/// deliberate reason the card is left-aligned here rather than
/// right-aligned as in the Rafd reference. A defensive dark gradient is
/// ALSO applied over the same left region (see [_LoginBackground]) so the
/// car stays hidden even at viewport sizes/aspect ratios where the card
/// alone might not fully cover it.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  late final AnimationController _entranceCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fade = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic),
        );
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_emailCtrl.text, _passwordCtrl.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashRouter()),
        (route) => false,
      );
    } else if (auth.authError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.authError!),
          backgroundColor: AppColors.statusRejected,
        ),
      );
    }
  }

  /// Language toggle is visual-only for now (matches the reference
  /// design's shape/format request) — the app has no wired i18n switcher
  /// yet (see `main.dart`'s hardcoded `Locale('ar')`). Tapping it
  /// acknowledges the tap rather than doing nothing silently.
  void _showLanguageComingSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تبديل اللغة قريبًا')));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _LoginBackground(),
          FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final formArgs = _LoginFormArgs(
                      formKey: _formKey,
                      emailCtrl: _emailCtrl,
                      passwordCtrl: _passwordCtrl,
                      obscure: _obscure,
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      onSubmit: _submit,
                      isLoading: auth.isLoading,
                      onLangTap: _showLanguageComingSoon,
                    );
                    if (constraints.maxWidth >= 900) {
                      return _WideLayout(args: formArgs);
                    }
                    return _NarrowLayout(args: formArgs);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bundles everything the login card / form needs, so [_WideLayout] and
/// [_NarrowLayout] don't have to repeat a long parameter list.
class _LoginFormArgs {
  const _LoginFormArgs({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.isLoading,
    required this.onLangTap,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final bool isLoading;
  final VoidCallback onLangTap;
}

/// Full-bleed background photo + scrim. The extra left-anchored dark
/// gradient (on top of the base uniform scrim) is the "safety net" that
/// keeps the source photo's parked car hidden regardless of screen
/// width/aspect ratio — see the class doc comment on [LoginScreen].
class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/login_bg.jpg',
          fit: BoxFit.cover,
          // Slight rightward bias: on narrow/portrait screens this keeps
          // the crop window centered on the building's entrance rather
          // than drifting toward the left (car) side of the source photo.
          alignment: const Alignment(0.3, 0.0),
        ),
        // Base uniform scrim — legibility for white tagline text anywhere
        // on the photo.
        Container(color: AppColors.navy.withValues(alpha: 0.32)),
        // Left-anchored defensive gradient — strong/near-opaque from the
        // left edge, fading out by ~60% of the width. This is what
        // guarantees the car stays hidden even where the floating card
        // itself doesn't reach (e.g. above/below the card, or on very
        // wide screens where little of the photo is cropped).
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.navy.withValues(alpha: 0.88),
                AppColors.navy.withValues(alpha: 0.88),
                AppColors.navy.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.42, 0.62],
            ),
          ),
        ),
        // Bottom vignette — grounds footer text placed near the bottom
        // of the screen (matches the previous PremiumMeshBackground's
        // treatment).
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.32),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Wide/web layout: card fixed on the LEFT, tagline block filling the
/// remaining space on the right (mirrored from the Rafd reference, which
/// had the card on the right — see [LoginScreen] doc comment for why).
class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.args});

  final _LoginFormArgs args;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 32),
      child: Row(
        textDirection: TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 420,
            child: SingleChildScrollView(child: _LoginCard(args: args)),
          ),
          const SizedBox(width: 48),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: const _TaglineBlock(),
          ),
        ],
      ),
    );
  }
}

/// Narrow/mobile layout: single scrollable column — condensed tagline,
/// then the card, then footer notes (same structure the screen had
/// before this redesign, just restyled internals).
class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({required this.args});

  final _LoginFormArgs args;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            children: [
              const Text(
                'معك خطوة بخطوة لإنجاز مهامك',
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineLg,
              ),
              const SizedBox(height: 32),
              _LoginCard(args: args),
              const SizedBox(height: 24),
              const Text(
                'الموظفون الجدد يسجّلون عبر رابط الدعوة المُرسل من المدير',
                textAlign: TextAlign.center,
                style: AppTextStyles.captionSm,
              ),
              const SizedBox(height: 20),
              Text(
                'Nay211 © 2026',
                textAlign: TextAlign.center,
                style: AppTextStyles.captionSm.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Right-side headline + sub-headline shown only on wide/web layouts,
/// mirroring the reference design's tagline block (which sat opposite
/// the card).
class _TaglineBlock extends StatelessWidget {
  const _TaglineBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'معك خطوة بخطوة لإنجاز مهامك',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.35,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'منصة صنعت من أجلك لتجعل مهامك أسهل',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

/// The floating pale "ice-blue" card — logo/brand block, language toggle,
/// and the login form itself. Shared by both wide and narrow layouts.
class _LoginCard extends StatelessWidget {
  const _LoginCard({required this.args});

  final _LoginFormArgs args;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: _LanguageTogglePill(onTap: args.onLangTap),
          ),
          const SizedBox(height: 4),
          const _BrandBlock(),
          const SizedBox(height: 24),
          Form(
            key: args.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AuthField(
                  label: 'البريد الإلكتروني',
                  controller: args.emailCtrl,
                  hint: 'example@domain.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'أدخل البريد الإلكتروني'
                      : null,
                ),
                const SizedBox(height: 16),
                _AuthField(
                  label: 'كلمة المرور',
                  controller: args.passwordCtrl,
                  hint: '••••••••',
                  icon: Icons.lock_outline,
                  obscureText: args.obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => args.onSubmit(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      args.obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textSecondary,
                      size: AppIconSize.md,
                    ),
                    onPressed: args.onToggleObscure,
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'أدخل كلمة المرور' : null,
                ),
                const SizedBox(height: 22),
                _GradientSubmitButton(
                  isLoading: args.isLoading,
                  onPressed: args.onSubmit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual-only Arabic/English pill switcher, top-left of the card —
/// matches the reference design's shape. Wrapped in [Alignment.topLeft]
/// via the parent's `Align` (direction-agnostic — always visually
/// top-left of the card regardless of the app's global RTL
/// [Directionality]).
class _LanguageTogglePill extends StatelessWidget {
  const _LanguageTogglePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.deepBlue,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: const Text(
                'العربية',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'English',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo mark + 3-word tagline + one-line platform description — mirrors
/// the reference card's "رفد / دعم . إسناد . تكامل / منظومة موحدة..."
/// composition, using NeoTask's own brand + copy.
class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/images/neotask_logo.png',
          width: 60,
          height: 60,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 10),
        Text(
          'تنظيم  .  تنفيذ  .  تتبع',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

/// Labeled input field styled to match the reference: a grey label ABOVE
/// a white rounded field with an inline icon, rather than a Material
/// floating [InputDecoration.labelText].
class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.suffixIcon,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, right: 2),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          // Email/password content is always Latin-script/LTR — without
          // pinning textDirection/textAlign explicitly, the field
          // inherits the app's global RTL Directionality (see
          // main.dart), which makes the caret jump and characters
          // visually reorder while typing (classic bidi glitch).
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.55),
              fontSize: 13,
            ),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(
              icon,
              size: AppIconSize.md,
              color: AppColors.textSecondary,
            ),
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(
                color: AppColors.deepBlue,
                width: 1.6,
              ),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

/// Full-width gradient login button — stays within the app's existing
/// two-hue ink-navy/gold palette (using [AppColors.deepBlue] →
/// [AppColors.steel]) rather than introducing the reference's unrelated
/// bright blue, while still reading as "a blue gradient button" matching
/// its shape/format.
class _GradientSubmitButton extends StatelessWidget {
  const _GradientSubmitButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [AppColors.deepBlue, AppColors.steel],
            ),
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'تسجيل الدخول',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
