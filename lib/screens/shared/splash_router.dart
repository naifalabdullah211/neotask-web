import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_ready.dart';
import '../auth/login_screen.dart';
import '../auth/manager_setup_screen.dart';
import '../auth/manager_welcome_screen.dart';
import '../auth/pending_approval_screen.dart';
import '../auth/register_via_invite_screen.dart';
import '../manager/manager_home_screen.dart';
import '../employee/employee_home_screen.dart';
import '../designer/designer_home_screen.dart';
import '../public/public_form_screen.dart';

class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  // NeoTask is an established production workspace with an existing manager.
  // Keep the historical bootstrap screen closed on signed-out devices even if
  // its legacy sentinel is missing; the authenticated manager repairs that
  // sentinel after login via AuthProvider.
  static const bool _managerBootstrapClosed = true;

  String? _inviteToken;
  String? _publicFormId;
  bool _inviteReady = true;
  bool _sessionReady = false;
  bool _managerStatusReady = false;
  bool _appReadyScheduled = false;
  bool _forceLogin = false;

  @override
  void initState() {
    super.initState();
    final token = Uri.base.queryParameters['invite'];
    _inviteToken = (token != null && token.isNotEmpty) ? token : null;
    final formId = Uri.base.queryParameters['form'];
    _publicFormId = (formId != null && formId.isNotEmpty) ? formId : null;
    _inviteReady = _inviteToken == null;
    _forceLogin = Uri.base.path.replaceAll(RegExp(r'/+$'), '') == '/login';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_initializeRoute());
    });
  }

  Future<void> _initializeRoute() async {
    final auth = context.read<AuthProvider>();
    try {
      // Never expose the signed-out Flutter route while Firebase is still
      // restoring an existing browser session. The HTML login stays visible
      // until this finishes, and the timeout prevents a slow Firestore request
      // from blocking the UI indefinitely.
      await auth.restoreSession().timeout(const Duration(seconds: 8));
    } catch (_) {
      // The route remains usable if Safari cannot restore the session.
    }
    if (!mounted) return;

    if (!auth.isLoggedIn && _inviteToken == null && !_forceLogin) {
      try {
        await FirestoreService.initManagerStatus();
      } catch (_) {
        // FirestoreService defaults to "manager exists" until it receives a
        // successful sentinel snapshot, so a network failure cannot expose
        // the one-time manager setup route.
      }
    }
    if (!mounted) return;

    setState(() {
      _sessionReady = true;
      _managerStatusReady = true;
    });
    if (_inviteToken != null) {
      unawaited(_prepareInvite());
    } else if (auth.isLoggedIn) {
      _notifyReadyAfterDestinationFrame();
    }
  }

  Future<void> _prepareInvite() async {
    try {
      await FirestoreService.initPublic();
    } finally {
      if (mounted) {
        setState(() => _inviteReady = true);
        _notifyReadyAfterDestinationFrame();
      }
    }
  }

  void _notifyReadyAfterDestinationFrame() {
    if (_appReadyScheduled) return;
    _appReadyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) notifyAppReady();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) return const _SessionBootstrapView();

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        Widget destination;

        if (_publicFormId != null) {
          destination = PublicFormScreen(formId: _publicFormId!);
        } else if (_inviteToken != null && !auth.isLoggedIn) {
          destination = _inviteReady
              ? RegisterViaInviteScreen(token: _inviteToken!)
              : const _InviteBootstrapView();
        } else if (!auth.isLoggedIn) {
          destination = !_forceLogin &&
                  !_managerBootstrapClosed &&
                  _managerStatusReady &&
                  !auth.managerExists
              ? const ManagerSetupScreen()
              : const LoginScreen();
        } else {
          final user = auth.currentUser!;
          if (user.accountStatus == AccountStatus.pendingApproval) {
            destination = const PendingApprovalScreen();
          } else if (user.role == UserRole.manager) {
            destination = user.managerWelcomeVersion < managerWelcomeVersion
                ? const ManagerWelcomeScreen()
                : const ManagerHomeScreen();
          } else if (user.role == UserRole.designer) {
            destination = const DesignerHomeScreen();
          } else {
            destination = const EmployeeHomeScreen();
          }
        }

        // Auth restoration may complete after the bounded startup timeout.
        // In that case the provider rebuild is the first moment an actual
        // authenticated destination exists, so release the HTML cover here.
        if (auth.isLoggedIn || destination is ManagerSetupScreen) {
          _notifyReadyAfterDestinationFrame();
        }

        return destination;
      },
    );
  }
}

class _SessionBootstrapView extends StatelessWidget {
  const _SessionBootstrapView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF6F8FB),
      body: SizedBox.shrink(),
    );
  }
}

class _InviteBootstrapView extends StatelessWidget {
  const _InviteBootstrapView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF071D3B),
      body: Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(
            color: Color(0xFF33D6A6),
            strokeWidth: 3,
          ),
        ),
      ),
    );
  }
}
