import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../shared/splash_router.dart';

/// Employee self-registration screen, reached ONLY via a manager-generated
/// single-use invite link (?invite=TOKEN). The token is validated up-front;
/// on successful registration the invite is permanently burned.
class RegisterViaInviteScreen extends StatefulWidget {
  final String token;
  const RegisterViaInviteScreen({super.key, required this.token});

  @override
  State<RegisterViaInviteScreen> createState() =>
      _RegisterViaInviteScreenState();
}

class _RegisterViaInviteScreenState extends State<RegisterViaInviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _employeeNumberCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  bool _tokenValid = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final invite = auth.validateInviteToken(widget.token);
      setState(() {
        _tokenValid = invite != null;
        _checked = true;
        if (invite?.expectedEmployeeName != null) {
          _nameCtrl.text = invite!.expectedEmployeeName!;
        }
      });
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _employeeNumberCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.registerViaInvite(
      token: widget.token,
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      employeeNumber: _employeeNumberCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashRouter()),
        (route) => false,
      );
    } else if (auth.authError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(auth.authError!),
            backgroundColor: AppColors.statusRejected),
      );
      setState(() => _tokenValid = auth.validateInviteToken(widget.token) != null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_tokenValid) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link_off_rounded,
                      size: 56, color: AppColors.statusRejected),
                  const SizedBox(height: 16),
                  const Text(
                    'رابط الدعوة غير صالح',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'إمّا أن هذا الرابط قد استُخدم مسبقًا من قِبل موظف آخر، أو أنه غير صحيح.\n'
                    'يرجى التواصل مع المدير للحصول على رابط دعوة جديد.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, height: 1.6),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const SplashRouter()),
                      (route) => false,
                    ),
                    child: const Text('العودة لتسجيل الدخول'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('إنشاء حساب موظف')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.mail_outline,
                                color: AppColors.deepBlue),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'دعوة صالحة — أكمل بياناتك للانضمام',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الاسم الكامل',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'أدخل الاسم' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'أدخل بريدًا إلكترونيًا صحيحًا'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _employeeNumberCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'الرقم الوظيفي',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'أدخل الرقم الوظيفي'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.length < 4)
                              ? 'كلمة المرور 4 أحرف على الأقل'
                              : null,
                        ),
                        const SizedBox(height: 22),
                        ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('إرسال طلب الانضمام'),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'بعد الإرسال سيصبح حسابك بانتظار موافقة المدير.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
