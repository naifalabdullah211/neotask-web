import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/premium_mesh_background.dart';
import '../shared/splash_router.dart';

/// One-time welcome screen shown ONLY immediately after the manager account
/// is created for the very first time (reached exclusively from
/// ManagerSetupScreen's success path). Never shown again afterwards — normal
/// logins go straight to ManagerHomeScreen via LoginScreen -> SplashRouter.
class ManagerWelcomeScreen extends StatefulWidget {
  const ManagerWelcomeScreen({super.key});

  @override
  State<ManagerWelcomeScreen> createState() => _ManagerWelcomeScreenState();
}

class _ManagerWelcomeScreenState extends State<ManagerWelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic),
        );
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashRouter()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PremiumMeshBackground(),
          FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
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
                          const SizedBox(height: 24),
                          const Text(
                            'أهلًا وسهلًا',
                            style: AppTextStyles.headlineLg,
                          ),
                          const SizedBox(height: 40),
                          _GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'دكتور محمد خلاوي',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'مدير برنامج الخدمات الصحية بالهيئة الملكية بينبع',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodySm,
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  height: 1,
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'نورت NeoTask',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'نتمنى أن ينال التطبيق رضاكم واستحسانكم، '
                                  'ونحن جاهزون لاستقبال اقتراحاتكم والعمل على '
                                  'التطوير المستمر.',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodySm,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _continue,
                              child: const Text('متابعة إلى لوحة التحكم'),
                            ),
                          ),
                        ],
                      ),
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

/// Glassmorphic surface, identical treatment to LoginScreen's card for
/// visual consistency across the auth flow.
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
          child: child,
        ),
      ),
    );
  }
}
