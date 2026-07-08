import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../shared/splash_router.dart';

/// First-run screen shown when NO manager account exists yet in the system.
/// Since this app has a single-manager flat hierarchy, this screen creates
/// that one manager account. Reached automatically by SplashRouter when
/// AuthProvider.managerExists == false.
class ManagerSetupScreen extends StatefulWidget {
  const ManagerSetupScreen({super.key});

  @override
  State<ManagerSetupScreen> createState() => _ManagerSetupScreenState();
}

class _ManagerSetupScreenState extends State<ManagerSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _employeeNumberCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

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
    await auth.ensureManagerExists(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      employeeNumber: _employeeNumberCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    final ok = await auth.login(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashRouter()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Image.asset('assets/images/neotask_logo.png',
                          fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'مرحبًا بك في NeoTask',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'لا يوجد حساب مدير بعد — أنشئ حساب المدير الرئيسي للبدء',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'إنشاء حساب المدير',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'الاسم الكامل',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'أدخل الاسم'
                                  : null,
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
                                  : const Text('إنشاء الحساب والدخول'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
