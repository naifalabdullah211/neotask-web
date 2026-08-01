import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'manager_welcome_screen.dart';

/// Shown when NO manager account exists yet (system/manager_lock absent)
/// AND no invite token is present in the URL. The manager self-registers by
/// typing their own name + employee number + password directly here — no
/// pre-seeded invite is required. After successful creation the manager is
/// logged in immediately and can invite employees via the existing
/// invite-link feature (manager_employees_tab.dart).
class ManagerSetupScreen extends StatefulWidget {
  const ManagerSetupScreen({super.key});

  @override
  State<ManagerSetupScreen> createState() => _ManagerSetupScreenState();
}

class _ManagerSetupScreenState extends State<ManagerSetupScreen> {
  static const _setupKey = 'NAIFALABDULLAH211@';

  final _formKey = GlobalKey<FormState>();
  final _setupKeyCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _employeeNumberCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  @override
  void dispose() {
    _setupKeyCtrl.dispose();
    _nameCtrl.dispose();
    _employeeNumberCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.ensureManagerExists(
      name: _nameCtrl.text.trim(),
      employeeNumber: _employeeNumberCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ManagerWelcomeScreen()),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/neotask_brand_mark.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'إنشاء حساب المدير',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'لا يوجد حساب مدير مُفعّل بعد. بصفتك أول مستخدم، أدخل '
                      'بياناتك لإنشاء حساب المدير.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _setupKeyCtrl,
                                obscureText: true,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.left,
                                decoration: const InputDecoration(
                                  labelText: 'مفتاح التأسيس',
                                  prefixIcon: Icon(Icons.key_outlined),
                                ),
                                validator: (v) => v == _setupKey
                                    ? null
                                    : 'مفتاح التأسيس غير صحيح',
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'الاسم الكامل',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'أدخل الاسم'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _employeeNumberCtrl,
                                keyboardType: TextInputType.number,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.left,
                                decoration: const InputDecoration(
                                  labelText: 'الرقم الوظيفي',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'أدخل الرقم الوظيفي'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordCtrl,
                                obscureText: _obscure,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.left,
                                decoration: InputDecoration(
                                  labelText: 'الرقم السري',
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
                                validator: (v) => (v == null || v.length < 6)
                                    ? 'الرقم السري 6 أحرف على الأقل'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _confirmPasswordCtrl,
                                obscureText: _obscure,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.left,
                                decoration: const InputDecoration(
                                  labelText: 'تأكيد الرقم السري',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                                validator: (v) => (v != _passwordCtrl.text)
                                    ? 'الرقمان السريان لا يتطابقان'
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
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('إنشاء الحساب'),
                              ),
                            ],
                          ),
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
