import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_i18n.dart';
import '../../providers/auth_provider.dart';
import '../../services/biometric_unlock_service.dart';
import '../../theme/app_theme.dart';

class BiometricUnlockScreen extends StatefulWidget {
  const BiometricUnlockScreen({
    super.key,
    required this.uid,
    required this.displayName,
    required this.onUnlocked,
    required this.onSignOut,
  });

  final String uid;
  final String displayName;
  final Future<void> Function() onUnlocked;
  final Future<void> Function() onSignOut;

  @override
  State<BiometricUnlockScreen> createState() =>
      _BiometricUnlockScreenState();
}

class _BiometricUnlockScreenState extends State<BiometricUnlockScreen> {
  final _passwordController = TextEditingController();
  bool _unlocking = false;
  bool _passwordMode = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _unlockWithBiometrics() async {
    if (_unlocking) return;
    setState(() {
      _unlocking = true;
      _error = null;
    });
    try {
      await BiometricUnlockService.unlock(widget.uid);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _biometricErrorMessage(error);
        _unlocking = false;
      });
      return;
    }
    if (!mounted) return;
    try {
      await widget.onUnlocked();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'تم التحقق بنجاح، لكن تعذّر فتح الجلسة. تحقق من الاتصال وحاول مرة أخرى.';
        _unlocking = false;
      });
    }
  }

  Future<void> _unlockWithPassword() async {
    if (_unlocking || _passwordController.text.isEmpty) return;
    setState(() {
      _unlocking = true;
      _error = null;
    });
    final error = await context.read<AuthProvider>().verifyCurrentPassword(
      _passwordController.text,
    );
    if (!mounted) return;
    if (error == null) {
      try {
        await widget.onUnlocked();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _unlocking = false;
          _error =
              'تم التحقق بنجاح، لكن تعذّر فتح الجلسة. تحقق من الاتصال وحاول مرة أخرى.';
        });
      }
      return;
    }
    setState(() {
      _unlocking = false;
      _error = error;
    });
  }

  Future<void> _signOut() async {
    if (_unlocking) return;
    setState(() {
      _unlocking = true;
      _error = null;
    });
    try {
      await widget.onSignOut();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _unlocking = false;
        _error = 'تعذّر تسجيل الخروج. أعد المحاولة.';
      });
    }
  }

  String _biometricErrorMessage(Object error) {
    return switch (BiometricUnlockService.failureFrom(error)) {
      BiometricFailure.cancelled =>
        'لم يكتمل التحقق. اضغط الزر وحاول مرة أخرى.',
      BiometricFailure.unsupported =>
        'هذا المتصفح لا يدعم Face ID. استخدم الرقم السري.',
      BiometricFailure.notEnrolled =>
        'Face ID غير مفعّل لهذا الحساب على هذا الجهاز.',
      BiometricFailure.invalidOrigin =>
        'يتطلب Face ID فتح نيوتاسك من رابطه الآمن المعتمد.',
      BiometricFailure.storageUnavailable =>
        'تعذّر قراءة إعداد Face ID على هذا الجهاز.',
      BiometricFailure.credentialMismatch =>
        'مفتاح Face ID لا يطابق هذا الحساب. استخدم الرقم السري.',
      BiometricFailure.failed =>
        'تعذّر التحقق عبر Face ID. حاول مرة أخرى أو استخدم الرقم السري.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _BiometricBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F2547).withValues(alpha: 0.2),
                          blurRadius: 42,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/neotask_brand_full.png',
                          width: 176,
                          height: 68,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 22),
                        Center(
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: AppColors.mintAccent.withValues(
                                alpha: 0.13,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.mintAccent.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                            ),
                            child: const Icon(
                              Icons.face_rounded,
                              color: AppColors.deepBlue,
                              size: 42,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'افتح نيوتاسك بـ Face ID',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          widget.displayName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (!_passwordMode) ...[
                          ElevatedButton.icon(
                            onPressed: _unlocking
                                ? null
                                : _unlockWithBiometrics,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            icon: _unlocking
                                ? const SizedBox(
                                    width: 19,
                                    height: 19,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.face_rounded),
                            label: Text(
                              _unlocking
                                  ? 'جارٍ التحقق...'
                                  : 'فتح بـ Face ID',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _unlocking
                                ? null
                                : () => setState(() {
                                    _passwordMode = true;
                                    _error = null;
                                  }),
                            child: const Text('استخدام الرقم السري بدلًا من ذلك'),
                          ),
                        ] else ...[
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                            autofocus: true,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _unlockWithPassword(),
                            decoration: InputDecoration(
                              labelText: context.tr('الرقم السري'),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: _unlocking ||
                                    _passwordController.text.isEmpty
                                ? null
                                : _unlockWithPassword,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                            ),
                            child: _unlocking
                                ? const SizedBox(
                                    width: 19,
                                    height: 19,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('فتح نيوتاسك'),
                          ),
                          TextButton(
                            onPressed: _unlocking
                                ? null
                                : () => setState(() {
                                    _passwordMode = false;
                                    _passwordController.clear();
                                    _error = null;
                                  }),
                            child: const Text('العودة إلى Face ID'),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.statusRejected,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'لا تصل صورة وجهك أو بصمتك إلى نيوتاسك',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: _unlocking ? null : _signOut,
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('تسجيل الخروج'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BiometricBackground extends StatelessWidget {
  const _BiometricBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/login_bg.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xED0F2547), Color(0xD91B3A6B)],
            ),
          ),
        ),
      ],
    );
  }
}
