import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../auth/pending_approval_screen.dart';
import '../auth/register_via_invite_screen.dart';
import '../auth/manager_setup_screen.dart';
import '../manager/manager_home_screen.dart';
import '../employee/employee_home_screen.dart';

class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  bool _checked = false;
  String? _inviteToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Detect an invite link of the form ".../?invite=TOKEN" (web only).
      // This lets the manager share a single-use registration URL.
      final uri = Uri.base;
      final token = uri.queryParameters['invite'];
      final auth = context.read<AuthProvider>();
      await auth.restoreSession();
      if (mounted) {
        setState(() {
          _inviteToken = (token != null && token.isNotEmpty) ? token : null;
          _checked = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _NeoTaskLogo(),
              SizedBox(height: 24),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    // If an invite token is present in the URL and there is no active
    // logged-in session, always show the registration screen first.
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (_inviteToken != null && !auth.isLoggedIn) {
          return RegisterViaInviteScreen(token: _inviteToken!);
        }
        if (!auth.isLoggedIn) {
          if (!auth.managerExists) return const ManagerSetupScreen();
          return const LoginScreen();
        }
        final user = auth.currentUser!;
        if (user.accountStatus == AccountStatus.pendingApproval) {
          return const PendingApprovalScreen();
        }
        if (user.role == UserRole.manager) {
          return const ManagerHomeScreen();
        }
        return const EmployeeHomeScreen();
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
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: 0.25),
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
