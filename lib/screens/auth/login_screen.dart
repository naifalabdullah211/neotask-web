import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../shared/splash_router.dart';

/// One responsive NeoTask sign-in experience for desktop, tablet and phone.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _employeeNumberCtrl = TextEditingController();
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
    _employeeNumberCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_employeeNumberCtrl.text, _passwordCtrl.text);
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
                      employeeNumberCtrl: _employeeNumberCtrl,
                      passwordCtrl: _passwordCtrl,
                      obscure: _obscure,
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      onSubmit: _submit,
                      isLoading: auth.isLoading,
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
    required this.employeeNumberCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.isLoading,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController employeeNumberCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final bool isLoading;
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Color(0xFFF6F8FB));
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
    return Row(
      textDirection: TextDirection.ltr,
      children: [
        Expanded(
          flex: 56,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: _LoginCard(args: args),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 44,
          child: Container(
            height: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 56),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF0F2948), Color(0xFF214C69)],
              ),
            ),
            child: const Center(child: _TaglineBlock()),
          ),
        ),
      ],
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 220,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF0F2948), Color(0xFF214C69)],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 54),
            child: const Center(child: _TaglineBlock(compact: true)),
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 184, 18, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  _LoginCard(args: args),
                  const SizedBox(height: 18),
                  const Text(
                    'الموظفون الجدد يسجّلون عبر رابط الدعوة المُرسل من المدير',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nay211 © 2026',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Right-side headline + sub-headline shown only on wide/web layouts,
/// mirroring the reference design's tagline block (which sat opposite
/// the card).
class _TaglineBlock extends StatelessWidget {
  const _TaglineBlock({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'مساحة عمل واحدة.\nإنجاز أوضح.',
          textAlign: compact ? TextAlign.center : TextAlign.right,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 25 : 38,
            fontWeight: FontWeight.w800,
            height: 1.35,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: compact ? 8 : 16),
        Text(
          'نظّم مهامك، تابع فريقك، وأنجز أعمالك اليومية بسهولة من أي جهاز.',
          textAlign: compact ? TextAlign.center : TextAlign.right,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: compact ? 12 : 15,
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
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 30),
      decoration: BoxDecoration(
        color: Colors.white,
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
          const _BrandBlock(),
          const SizedBox(height: 24),
          Form(
            key: args.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AuthField(
                  label: 'الرقم الوظيفي',
                  controller: args.employeeNumberCtrl,
                  hint: 'مثال: 10234',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'أدخل الرقم الوظيفي'
                      : null,
                ),
                const SizedBox(height: 16),
                _AuthField(
                  label: 'الرقم السري',
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
                      (v == null || v.isEmpty) ? 'أدخل الرقم السري' : null,
                ),
                const SizedBox(height: 22),
                _GradientSubmitButton(
                  isLoading: args.isLoading,
                  onPressed: args.onSubmit,
                ),
                const SizedBox(height: 14),
                const Text(
                  'بياناتك آمنة ومشفرة بالكامل',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
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
          'assets/images/neotask_brand_full.png',
          width: 190,
          height: 76,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 12),
        const Text(
          'مرحبًا بعودتك',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'سجّل الدخول للوصول إلى مساحة عملك',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
