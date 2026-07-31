import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../auth/pending_approval_screen.dart';
import '../auth/register_via_invite_screen.dart';
import '../auth/manager_setup_screen.dart';
import '../manager/manager_home_screen.dart';
import '../employee/employee_home_screen.dart';
import '../designer/designer_home_screen.dart';

class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  bool _checked = false;
  String? _inviteToken;
  String? _startupMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final uri = Uri.base;
    final token = uri.queryParameters['invite'];
    final auth = context.read<AuthProvider>();

    try {
      // Never allow Firestore/session restoration to trap the whole app on
      // the splash screen. A slow or blocked network now falls back to the
      // appropriate setup/login route instead of spinning forever.
      await auth.restoreSession().timeout(const Duration(seconds: 12));
    } catch (_) {
      _startupMessage =
          'تعذّر استعادة الجلسة تلقائيًا، يمكنك تسجيل الدخول من جديد';
    }

    if (!mounted) return;
    setState(() {
      _inviteToken = (token != null && token.isNotEmpty) ? token : null;
      _checked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _NeoTaskLogo(),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 14),
              const Text(
                'جار تشغيل NeoTask',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'لن يستغرق أكثر من 12 ثانية',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        Widget destination;

        if (_inviteToken != null && !auth.isLoggedIn) {
          destination = RegisterViaInviteScreen(token: _inviteToken!);
        } else if (!auth.isLoggedIn) {
          destination = auth.managerExists
              ? const LoginScreen()
              : const ManagerSetupScreen();
        } else {
          final user = auth.currentUser!;
          if (user.accountStatus == AccountStatus.pendingApproval) {
            destination = const PendingApprovalScreen();
          } else if (user.role == UserRole.manager) {
            destination = const ManagerHomeScreen();
          } else if (user.role == UserRole.designer) {
            destination = const DesignerHomeScreen();
          } else {
            destination = const EmployeeHomeScreen();
          }
        }

        if (_startupMessage == null) return destination;

        return Stack(
          children: [
            Positioned.fill(child: destination),
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: SafeArea(
                child: Material(
                  color: const Color(0xFF1B3A6B),
                  borderRadius: BorderRadius.circular(14),
                  elevation: 6,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _startupMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NeoTaskLogo extends StatelessWidget {
  const _NeoTaskLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
    );
  }
}
