import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/biometric_unlock_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_ready.dart';
import '../../utils/manager_setup_route.dart';
import '../auth/biometric_unlock_screen.dart';
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

class _SplashRouterState extends State<SplashRouter>
    with WidgetsBindingObserver {
  String? _inviteToken;
  String? _publicFormId;
  bool _inviteReady = true;
  bool _sessionReady = false;
  bool _managerStatusReady = false;
  bool _appReadyScheduled = false;
  bool _forceLogin = false;
  String? _biometricUid;
  bool _biometricCheckInFlight = false;
  bool _biometricRequired = false;
  bool _biometricUnlocked = false;
  bool _biometricOfferScheduled = false;
  String? _deferredBiometricUid;
  bool _completingDeferredSession = false;
  OverlayEntry? _biometricRelockOverlay;
  bool _lateIdentityRetryScheduled = false;
  int _routeInitializationEpoch = 0;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BiometricUnlockService.configurationRevision.addListener(
      _handleBiometricConfigurationChanged,
    );
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

  @override
  void dispose() {
    _removeBiometricRelockOverlay();
    BiometricUnlockService.configurationRevision.removeListener(
      _handleBiometricConfigurationChanged,
    );
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleBiometricConfigurationChanged() {
    unawaited(_refreshBiometricConfiguration());
  }

  Future<void> _refreshBiometricConfiguration() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || user.accountStatus != AccountStatus.active) return;
    final enabled = await BiometricUnlockService.isEnabled(user.uid);
    if (!mounted || context.read<AuthProvider>().currentUser?.uid != user.uid) {
      return;
    }
    setState(() {
      _biometricUid = user.uid;
      _biometricRequired = enabled;
      // Enrollment itself just completed an OS-level verification. Do not
      // surprise the user with another prompt until the next real lock event.
      _biometricUnlocked = true;
      _biometricOfferScheduled = enabled;
    });
    BiometricUnlockService.setApplicationLocked(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed || _backgroundedAt == null) return;

    final awayFor = DateTime.now().difference(_backgroundedAt!);
    _backgroundedAt = null;
    if (awayFor >= const Duration(seconds: 15) &&
        _biometricRequired &&
        _biometricUnlocked &&
        mounted) {
      BiometricUnlockService.setApplicationLocked(true);
      setState(() => _biometricUnlocked = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || (ModalRoute.of(context)?.isCurrent ?? true)) return;
        _showBiometricRelockOverlay();
      });
    }
  }

  void _showBiometricRelockOverlay() {
    if (_biometricRelockOverlay != null || !mounted) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || !_biometricRequired || _biometricUnlocked) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      opaque: true,
      builder: (_) => BiometricUnlockScreen(
        uid: user.uid,
        displayName: user.name,
        onUnlocked: () async {
          if (!mounted) return;
          setState(() => _biometricUnlocked = true);
          _removeBiometricRelockOverlay();
          BiometricUnlockService.setApplicationLocked(false);
        },
        onSignOut: _signOutFromBiometricGate,
      ),
    );
    _biometricRelockOverlay = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  void _removeBiometricRelockOverlay() {
    final entry = _biometricRelockOverlay;
    if (entry == null) return;
    _biometricRelockOverlay = null;
    entry.remove();
    entry.dispose();
  }

  Future<void> _signOutFromBiometricGate() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    _removeBiometricRelockOverlay();
    BiometricUnlockService.setApplicationLocked(false);
    setState(() {
      _deferredBiometricUid = null;
      _biometricUid = null;
      _biometricRequired = false;
      _biometricUnlocked = false;
    });
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashRouter()),
      (route) => false,
    );
  }

  Future<void> _initializeRoute() async {
    final initializationEpoch = ++_routeInitializationEpoch;
    final auth = context.read<AuthProvider>();
    if (_publicFormId != null) {
      // Public forms must not hydrate a persisted employee session in the
      // background. Their Firestore rules and screen load are intentionally
      // independent from authenticated application data.
      setState(() {
        _sessionReady = true;
        _managerStatusReady = true;
      });
      BiometricUnlockService.setApplicationLocked(false);
      _notifyReadyAfterDestinationFrame();
      return;
    }

    String? firebaseUid;
    var identityCheckCompleted = false;
    final identityFuture = auth.restoredFirebaseUid();
    try {
      // Resolve only Firebase's persisted identity first. This deliberately
      // does not start Firestore listeners: when a local biometric gate is
      // enabled, no application data is hydrated until the gate succeeds.
      firebaseUid = await identityFuture.timeout(
        const Duration(seconds: 8),
      );
      identityCheckCompleted = true;
    } on TimeoutException {
      // Keep a manual route usable now, but retry the gate as soon as the
      // original Firebase hydration actually settles (for example at 8.1s).
      unawaited(_retryAfterLateIdentity(identityFuture));
    } catch (_) {
      // A browser that cannot restore Firebase's identity still gets a usable
      // manual sign-in route. We do not start authenticated data listeners
      // when the identity check itself is indeterminate.
    }
    if (!_isCurrentInitialization(initializationEpoch)) return;

    var interactiveLogin = false;
    var firebaseBiometricEnabled = false;
    if (firebaseUid != null) {
      interactiveLogin = await BiometricUnlockService.consumeInteractiveLogin(
        firebaseUid,
      );
      firebaseBiometricEnabled = await BiometricUnlockService.isEnabled(
        firebaseUid,
      );
      if (!_isCurrentInitialization(initializationEpoch)) return;
      if (!interactiveLogin && firebaseBiometricEnabled) {
        BiometricUnlockService.setApplicationLocked(true);
        setState(() {
          _sessionReady = true;
          _managerStatusReady = true;
          _deferredBiometricUid = firebaseUid;
          _biometricUid = firebaseUid;
          _biometricRequired = true;
          _biometricUnlocked = false;
        });
        _notifyReadyAfterDestinationFrame();
        return;
      }
    }

    if (identityCheckCompleted) {
      try {
        await auth.restoreSession().timeout(const Duration(seconds: 12));
      } catch (_) {
        // Keep the login route usable on a transient Firestore failure. A late
        // provider update will still rebuild this router if restoration finishes.
      }
    }
    if (!_isCurrentInitialization(initializationEpoch)) return;

    if (!auth.isLoggedIn && _inviteToken == null && !_forceLogin) {
      try {
        await FirestoreService.initManagerStatus();
      } catch (_) {
        // FirestoreService defaults to "manager exists" until it receives a
        // successful sentinel snapshot, so a network failure cannot expose
        // the one-time manager setup route.
      }
    }
    if (!_isCurrentInitialization(initializationEpoch)) return;

    String? biometricUid;
    var biometricEnabled = false;
    final restoredUser = auth.currentUser;
    if (restoredUser != null &&
        restoredUser.accountStatus == AccountStatus.active) {
      biometricUid = restoredUser.uid;
      biometricEnabled = await BiometricUnlockService.isEnabled(
        restoredUser.uid,
      );
    }
    if (!_isCurrentInitialization(initializationEpoch)) return;

    final resolvedBiometricUid = biometricUid ??
        (interactiveLogin ? firebaseUid : null);
    final resolvedBiometricRequired = biometricUid != null
        ? biometricEnabled
        : interactiveLogin && firebaseBiometricEnabled;

    setState(() {
      _sessionReady = true;
      _managerStatusReady = true;
      _biometricUid = resolvedBiometricUid;
      _biometricRequired = resolvedBiometricRequired;
      _biometricUnlocked = interactiveLogin || !resolvedBiometricRequired;
    });
    BiometricUnlockService.setApplicationLocked(
      resolvedBiometricRequired && !interactiveLogin,
    );
    if (_inviteToken != null) {
      unawaited(_prepareInvite());
    } else if (auth.isLoggedIn) {
      _notifyReadyAfterDestinationFrame();
    }
  }

  bool _isCurrentInitialization(int epoch) {
    return mounted && epoch == _routeInitializationEpoch;
  }

  Future<void> _retryAfterLateIdentity(Future<String?> identityFuture) async {
    if (_lateIdentityRetryScheduled) return;
    _lateIdentityRetryScheduled = true;
    try {
      await identityFuture;
    } catch (_) {
      _lateIdentityRetryScheduled = false;
      return;
    }
    if (!mounted) return;
    if (context.read<AuthProvider>().isLoading) {
      _lateIdentityRetryScheduled = false;
      return;
    }
    _lateIdentityRetryScheduled = false;
    await _initializeRoute();
  }

  Future<void> _completeDeferredSession() async {
    final deferredUid = _deferredBiometricUid;
    if (deferredUid == null || _completingDeferredSession) return;
    _completingDeferredSession = true;

    try {
      await context
          .read<AuthProvider>()
          .restoreSession(expectedUid: deferredUid)
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      _completingDeferredSession = false;
      rethrow;
    }
    if (!mounted) return;

    final restoredUser = context.read<AuthProvider>().currentUser;
    setState(() {
      _completingDeferredSession = false;
      _deferredBiometricUid = null;
      if (restoredUser?.uid == deferredUid) {
        _biometricUid = deferredUid;
        _biometricRequired = true;
        _biometricUnlocked = true;
      } else {
        _biometricUid = null;
        _biometricRequired = false;
        _biometricUnlocked = false;
      }
    });
    BiometricUnlockService.setApplicationLocked(false);
    if (restoredUser == null && _inviteToken != null) {
      unawaited(_prepareInvite());
    }
  }

  void _scheduleBiometricCheck(AppUser user) {
    if (_biometricCheckInFlight || _biometricUid == user.uid) return;
    _biometricCheckInFlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final enabled = await BiometricUnlockService.isEnabled(user.uid);
      if (!mounted) return;
      setState(() {
        _biometricCheckInFlight = false;
        _biometricUid = user.uid;
        _biometricRequired = enabled;
        _biometricUnlocked = !enabled;
        _biometricOfferScheduled = false;
      });
      BiometricUnlockService.setApplicationLocked(enabled);
    });
  }

  void _scheduleBiometricOffer(AppUser user) {
    if (_biometricOfferScheduled || _biometricRequired) return;
    _biometricOfferScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final shouldOffer = await BiometricUnlockService.shouldOfferEnrollment(
        user.uid,
      );
      if (!mounted || !shouldOffer) return;
      final currentUser = context.read<AuthProvider>().currentUser;
      if (currentUser?.uid != user.uid ||
          currentUser?.accountStatus != AccountStatus.active) {
        return;
      }

      var enrollmentInProgress = false;
      Object? enrollmentError;
      final enable = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            icon: const Icon(
              Icons.face_rounded,
              color: AppColors.deepBlue,
              size: 36,
            ),
            title: const Text('تفعيل Face ID على هذا الجهاز؟'),
            content: const Text(
              'بعد التفعيل ستفتح جلسة نيوتاسك المحفوظة ببصمة الوجه بدل كتابة الرقم السري في كل مرة.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: enrollmentInProgress
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text('لاحقًا'),
              ),
              ElevatedButton.icon(
                onPressed: enrollmentInProgress
                    ? null
                    : () async {
                        setDialogState(() => enrollmentInProgress = true);
                        try {
                          // Keep WebAuthn in this button's activation chain.
                          // Safari may reject credentials.create() if it runs
                          // only after the dialog result has been awaited.
                          await BiometricUnlockService.enroll(
                            uid: user.uid,
                            employeeNumber: user.employeeNumber,
                            displayName: user.name,
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        } catch (error) {
                          enrollmentError = error;
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        }
                      },
                icon: enrollmentInProgress
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.face_rounded),
                label: Text(
                  enrollmentInProgress ? 'جارٍ التحقق...' : 'تفعيل Face ID',
                ),
              ),
            ],
          ),
        ),
      );

      if (enable != true) {
        if (enrollmentError == null) {
          await BiometricUnlockService.dismissEnrollmentOffer(user.uid);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_biometricEnrollmentError(enrollmentError!)),
              backgroundColor: AppColors.statusRejected,
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _biometricUid = user.uid;
        _biometricRequired = true;
        _biometricUnlocked = true;
      });
      BiometricUnlockService.setApplicationLocked(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تفعيل Face ID على هذا الجهاز'),
          backgroundColor: AppColors.statusApproved,
        ),
      );
    });
  }

  String _biometricEnrollmentError(Object error) {
    return switch (BiometricUnlockService.failureFrom(error)) {
      BiometricFailure.cancelled =>
        'لم يكتمل تفعيل Face ID. يمكنك تفعيله لاحقًا من الإعدادات.',
      BiometricFailure.unsupported =>
        'Face ID غير مدعوم في هذا المتصفح أو الجهاز.',
      BiometricFailure.invalidOrigin =>
        'افتح نيوتاسك من رابطه الآمن المعتمد لتفعيل Face ID.',
      BiometricFailure.storageUnavailable =>
        'تعذّر حفظ إعداد Face ID على هذا الجهاز.',
      _ => 'تعذّر تفعيل Face ID. حاول مرة أخرى من الإعدادات.',
    };
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

        if (_deferredBiometricUid != null) {
          destination = BiometricUnlockScreen(
            uid: _deferredBiometricUid!,
            displayName: 'حسابك في نيوتاسك',
            onUnlocked: _completeDeferredSession,
            onSignOut: _signOutFromBiometricGate,
          );
        } else if (_publicFormId != null) {
          destination = PublicFormScreen(formId: _publicFormId!);
        } else if (_inviteToken != null && !auth.isLoggedIn) {
          destination = _inviteReady
              ? RegisterViaInviteScreen(token: _inviteToken!)
              : const _InviteBootstrapView();
        } else if (!auth.isLoggedIn) {
          destination = shouldShowManagerSetup(
                forceLogin: _forceLogin,
                managerStatusReady: _managerStatusReady,
                managerExists: auth.managerExists,
              )
              ? const ManagerSetupScreen()
              : const LoginScreen();
        } else {
          final user = auth.currentUser!;
          if (user.accountStatus == AccountStatus.pendingApproval) {
            destination = const PendingApprovalScreen();
          } else if (_biometricUid != user.uid) {
            _scheduleBiometricCheck(user);
            destination = const _BiometricBootstrapView();
          } else if (_biometricRequired && !_biometricUnlocked) {
            destination = BiometricUnlockScreen(
              uid: user.uid,
              displayName: user.name,
              onUnlocked: () async {
                if (mounted) {
                  setState(() => _biometricUnlocked = true);
                  BiometricUnlockService.setApplicationLocked(false);
                }
              },
              onSignOut: _signOutFromBiometricGate,
            );
          } else if (user.hasManagerAccess) {
            destination = user.role == UserRole.manager &&
                    user.managerWelcomeVersion < managerWelcomeVersion
                ? const ManagerWelcomeScreen()
                : const ManagerHomeScreen();
          } else if (user.role == UserRole.designer) {
            destination = const DesignerHomeScreen();
          } else {
            destination = const EmployeeHomeScreen();
          }
          if (user.accountStatus == AccountStatus.active &&
              _biometricUid == user.uid &&
              !_biometricRequired) {
            _scheduleBiometricOffer(user);
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

class _BiometricBootstrapView extends StatelessWidget {
  const _BiometricBootstrapView();

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
