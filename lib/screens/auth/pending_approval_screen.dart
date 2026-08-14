import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';
import '../shared/splash_router.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final locale = context.watch<LocaleProvider>();
    final user = auth.currentUser;
    final english = !locale.isArabic;
    final name = user?.name ?? '';
    final employeeNumber = user?.employeeNumber ?? '';

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: AppElevation.mediumShadow,
                      ),
                      child: Image.asset(
                        'assets/images/neotask_brand_mark.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const Text(
                      'طلبك قيد المراجعة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      english
                          ? 'Your NeoTask account is waiting for manager approval.'
                          : 'حسابك في NeoTask بانتظار اعتماد المدير',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        boxShadow: AppElevation.mediumShadow,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.statusPending.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: const Icon(
                              Icons.hourglass_top_rounded,
                              color: AppColors.statusPending,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            english
                                ? (name.isEmpty
                                      ? 'Your join request was sent successfully. It will become active after the manager approves your account.'
                                      : 'Hello $name, your join request was sent successfully. It will become active after the manager approves your account.')
                                : (name.isEmpty
                                      ? 'تم إرسال طلب انضمامك بنجاح، وسيصبح حسابك فعالًا بعد موافقة المدير.'
                                      : 'مرحبًا $name، تم إرسال طلب انضمامك بنجاح، وسيصبح حسابك فعالًا بعد موافقة المدير.'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              height: 1.65,
                            ),
                          ),
                          if (employeeNumber.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.lg),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FA),
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.badge_outlined,
                                    size: 17,
                                    color: AppColors.deepBlue,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    english
                                        ? 'Employee ID: $employeeNumber'
                                        : 'الرقم الوظيفي: $employeeNumber',
                                    style: const TextStyle(
                                      color: AppColors.deepBlue,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xxl),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await context.read<AuthProvider>().logout();
                                if (context.mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (_) => const SplashRouter(),
                                    ),
                                    (route) => false,
                                  );
                                }
                              },
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('تسجيل الخروج'),
                            ),
                          ),
                        ],
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
