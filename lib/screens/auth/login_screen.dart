import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/premium_mesh_background.dart';
import '../shared/splash_router.dart';

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

  /// Opens the "forgot password" dialog. Pre-fills the email field from
  /// [_emailCtrl] if the user already typed one on the login form.
  Future<void> _showForgotPasswordDialog() async {
    final resetEmailCtrl = TextEditingController(text: _emailCtrl.text);
    final resetFormKey = GlobalKey<FormState>();
    bool isSending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('نسيت كلمة المرور؟'),
              content: Form(
                key: resetFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Explicit confirmation of ownership: the employee or
                    // manager types the new password themselves via the
                    // emailed link — the system/manager never sets or sees
                    // it. This is the exact assurance requested.
                    // NOTE: AppTextStyles.bodySm hardcodes Colors.white70,
                    // tuned for the dark glass-card login background — but
                    // AlertDialog renders on a white surface, so that
                    // style must be overridden here or the text is
                    // invisible (white-on-white).
                    Text(
                      'سيُرسَل رابط إعادة تعيين كلمة المرور إلى البريد '
                      'الإلكتروني المسجَّل. كلمة المرور الجديدة سيُدخلها '
                      'الموظف أو المدير بنفسه عبر ذلك الرابط، ولن يطّلع '
                      'عليها أو يحددها أي شخص آخر.',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: resetEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'أدخل البريد الإلكتروني'
                          : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          if (!(resetFormKey.currentState?.validate() ??
                              false)) {
                            return;
                          }
                          setDialogState(() => isSending = true);
                          final auth = context.read<AuthProvider>();
                          final error = await auth.sendPasswordResetEmail(
                            resetEmailCtrl.text,
                          );
                          if (!dialogContext.mounted) return;
                          Navigator.of(dialogContext).pop();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                error ??
                                    'تم إرسال رابط إعادة التعيين، تحقّق من '
                                        'بريدك الإلكتروني',
                              ),
                              backgroundColor: error != null
                                  ? AppColors.statusRejected
                                  : AppColors.statusApproved,
                            ),
                          );
                        },
                  child: isSending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('إرسال رابط إعادة التعيين'),
                ),
              ],
            );
          },
        );
      },
    );
    resetEmailCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PremiumMeshBackground(),
          FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: _buildContent(context, auth),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, AuthProvider auth) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                Container(
                  width: 240,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/neotask_logo_full.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('مهامك أسهل', style: AppTextStyles.bodySm),
                const SizedBox(height: 40),
                _GlassCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'تسجيل الدخول',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.titleMd,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          // Email addresses are always Latin-script/LTR
                          // content. Without pinning textDirection/textAlign
                          // explicitly, the field inherits the app's global
                          // RTL Directionality (see main.dart), which makes
                          // the caret jump and characters visually reorder
                          // while typing (classic bidi glitch) — this is the
                          // "لخبطة عند الكتابة" the user reported.
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'أدخل البريد الإلكتروني'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          // Same LTR pin as the email field above — most
                          // passwords are Latin/ASCII, so force LTR to avoid
                          // the same bidi caret-jump glitch while typing.
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'أدخل كلمة المرور'
                              : null,
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: auth.isLoading
                                ? null
                                : _showForgotPasswordDialog,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 32),
                            ),
                            child: const Text('نسيت كلمة المرور؟'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: auth.isLoading ? null : _submit,
                          child: auth.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('دخول'),
                        ),
                      ],
                    ),
                  ),
                ),
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
      ),
    );
  }
}

/// Glassmorphic surface: frosted blur + translucent tint + thin light
/// border, replacing the previous flat opaque white card.
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: child,
          ),
        ),
      ),
    );
  }
}
