import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _section(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start + startMarker.length);
  expect(start, greaterThanOrEqualTo(0), reason: 'Missing $startMarker');
  expect(end, greaterThan(start), reason: 'Missing $endMarker');
  return source.substring(start, end);
}

void main() {
  test('biometric facade keeps web and non-web implementations separated', () {
    final facade = File(
      'lib/services/biometric_unlock_service.dart',
    ).readAsStringSync();
    final webPlatform = File(
      'lib/services/biometric_unlock_platform_web.dart',
    ).readAsStringSync();

    expect(
      facade,
      contains(
        "if (dart.library.html) 'biometric_unlock_platform_web.dart'",
      ),
    );
    expect(facade, contains('class BiometricUnlockService'));
    expect(facade, contains('platform.consumeInteractiveLogin(uid)'));
    expect(webPlatform, contains("'neoTaskBiometrics'"));
    for (final method in const [
      'isSupported',
      'isEnabled',
      'enroll',
      'unlock',
      'disable',
      'markInteractiveLogin',
      'consumeInteractiveLogin',
    ]) {
      expect(webPlatform, contains("'$method'"));
    }
  });

  test('persisted app data remains behind the biometric gate', () {
    final source = File(
      'lib/screens/shared/splash_router.dart',
    ).readAsStringSync();
    final initialization = _section(
      source,
      'Future<void> _initializeRoute()',
      'Future<void> _completeDeferredSession()',
    );

    final identityCheck = initialization.indexOf('auth.restoredFirebaseUid()');
    final biometricCheck = initialization.indexOf(
      'BiometricUnlockService.isEnabled',
    );
    final fullRestore = initialization.indexOf('await auth.restoreSession()');

    expect(identityCheck, greaterThanOrEqualTo(0));
    expect(biometricCheck, greaterThan(identityCheck));
    expect(fullRestore, greaterThan(biometricCheck));
    expect(initialization, contains('_deferredBiometricUid = firebaseUid'));
    expect(
      initialization,
      contains('if (!interactiveLogin && firebaseBiometricEnabled)'),
    );
    expect(initialization, contains('resolvedBiometricUid'));
    expect(initialization, contains('resolvedBiometricRequired'));
    expect(initialization, contains('++_routeInitializationEpoch'));
    expect(
      RegExp(r'_isCurrentInitialization\(initializationEpoch\)')
          .allMatches(initialization)
          .length,
      greaterThanOrEqualTo(5),
    );

    final gateBranchStart = initialization.indexOf(
      'if (!interactiveLogin && firebaseBiometricEnabled)',
    );
    final gateBranchReturn = initialization.indexOf('return;', gateBranchStart);
    expect(gateBranchReturn, greaterThan(gateBranchStart));
    expect(gateBranchReturn, lessThan(fullRestore));

    expect(source, contains('if (_deferredBiometricUid != null)'));
    expect(source, contains('onUnlocked: _completeDeferredSession'));

    final incomingCallGate = File(
      'lib/widgets/incoming_call_gate.dart',
    ).readAsStringSync();
    expect(incomingCallGate, contains('GlobalKey _persistentChildKey'));
    expect(incomingCallGate, contains('KeyedSubtree('));
    expect(incomingCallGate, contains('applicationLocked.addListener'));
    expect(incomingCallGate, contains('applicationLocked.value'));
  });

  test('unlock screen provides password reauthentication fallback', () {
    final screen = File(
      'lib/screens/auth/biometric_unlock_screen.dart',
    ).readAsStringSync();
    final auth = File('lib/providers/auth_provider.dart').readAsStringSync();

    expect(screen, contains('BiometricUnlockService.unlock(widget.uid)'));
    expect(screen, contains('verifyCurrentPassword('));
    expect(screen, contains('استخدام الرقم السري بدلًا من ذلك'));
    expect(screen, contains('العودة إلى Face ID'));
    expect(screen, contains('onSignOut'));
    expect(screen, contains('تسجيل الخروج'));
    expect(auth, contains('reauthenticateWithCredential(credential)'));
    expect(
      auth,
      contains('Future<String?> verifyCurrentPassword(String password)'),
    );
  });

  test('startup enrollment and background relock stay gesture-safe', () {
    final router = File(
      'lib/screens/shared/splash_router.dart',
    ).readAsStringSync();
    final offer = _section(
      router,
      'void _scheduleBiometricOffer(',
      'String _biometricEnrollmentError(',
    );

    expect(offer, contains('StatefulBuilder('));
    expect(offer, contains('onPressed: enrollmentInProgress'));
    expect(offer, contains('await BiometricUnlockService.enroll('));
    expect(
      offer.indexOf('await BiometricUnlockService.enroll('),
      lessThan(offer.indexOf('Navigator.of(dialogContext).pop(true)')),
    );
    expect(router, contains('OverlayEntry('));
    expect(router, contains('rootOverlay: true'));
    expect(router, contains('_showBiometricRelockOverlay()'));
  });

  test('settings expose explicit enrollment and disable controls', () {
    final settings = File(
      'lib/screens/shared/settings_screen.dart',
    ).readAsStringSync();

    expect(settings, contains('BiometricUnlockService.enroll('));
    expect(settings, contains('BiometricUnlockService.disable('));
    expect(settings, contains('الدخول البيومتري'));
    expect(settings, contains('فتح بـ Face ID'));
  });

  test('WebAuthn bridge requires user verification without storing secrets', () {
    final bridge = File('web/biometric_unlock.js').readAsStringSync();
    final requiredVerificationCount = RegExp(
      "userVerification: 'required'",
    ).allMatches(bridge).length;

    expect(requiredVerificationCount, greaterThanOrEqualTo(2));
    expect(bridge, contains("authenticatorAttachment: 'platform'"));
    expect(bridge, contains("const RECORD_PREFIX = 'neotask.biometric.v1.'"));
    expect(bridge, contains(r'${RECORD_PREFIX}${requireUid(uid)}'));
    expect(bridge.toLowerCase(), isNot(contains('password')));
    expect(bridge, isNot(contains('clientDataJSON')));
    expect(bridge, isNot(contains('authenticatorData')));
    expect(bridge, isNot(contains('signature')));
  });

  test('gesture-bound WebAuthn calls preserve Safari user activation', () {
    final bridge = File('web/biometric_unlock.js').readAsStringSync();
    final enrollment = _section(
      bridge,
      'async function enroll(',
      'async function unlock(',
    );
    final unlock = _section(
      bridge,
      'async function unlock(',
      'async function isEnabled(',
    );

    expect(bridge, contains('function hasWebAuthnPrimitives()'));
    expect(enrollment, contains('hasWebAuthnPrimitives()'));
    expect(enrollment, isNot(contains('await isSupported()')));
    expect(unlock, contains('hasWebAuthnPrimitives()'));
    expect(unlock, isNot(contains('await isSupported()')));
  });
}
