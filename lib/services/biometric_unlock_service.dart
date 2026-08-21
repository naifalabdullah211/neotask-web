import 'package:flutter/foundation.dart';

import 'biometric_unlock_platform_stub.dart'
    if (dart.library.html) 'biometric_unlock_platform_web.dart'
    as platform;

/// Device-local biometric gate for an already-restored Firebase session.
///
/// On iPhone/iPad this is backed by WebAuthn and the platform passkey prompt,
/// which uses Face ID (or the device passcode fallback chosen by iOS). The
/// private key and biometric template never reach NeoTask.
class BiometricUnlockService {
  const BiometricUnlockService._();

  /// Lets the active router react immediately when Settings enables or
  /// disables the device-local gate, without persisting account-wide state.
  static final ValueNotifier<int> configurationRevision = ValueNotifier(0);

  /// Shared runtime lock state for top-level features (such as incoming call
  /// presentation) that live above SplashRouter in the widget tree.
  static final ValueNotifier<bool> applicationLocked = ValueNotifier(false);

  static void setApplicationLocked(bool locked) {
    if (applicationLocked.value != locked) applicationLocked.value = locked;
  }

  static Future<bool> isSupported() => platform.isSupported();

  static Future<bool> isEnabled(String uid) => platform.isEnabled(uid);

  static Future<bool> shouldOfferEnrollment(String uid) =>
      platform.shouldOfferEnrollment(uid);

  static Future<void> dismissEnrollmentOffer(String uid) =>
      platform.dismissEnrollmentOffer(uid);

  static Future<void> enroll({
    required String uid,
    required String employeeNumber,
    required String displayName,
  }) async {
    await platform.enroll(
      uid: uid,
      employeeNumber: employeeNumber,
      displayName: displayName,
    );
    configurationRevision.value += 1;
  }

  static Future<void> unlock(String uid) => platform.unlock(uid);

  static Future<void> disable(String uid) async {
    await platform.disable(uid);
    configurationRevision.value += 1;
  }

  static Future<void> markInteractiveLogin(String uid) =>
      platform.markInteractiveLogin(uid);

  static Future<bool> consumeInteractiveLogin(String uid) =>
      platform.consumeInteractiveLogin(uid);

  static BiometricFailure failureFrom(Object error) {
    final value = error.toString();
    if (value.contains('biometric-cancelled')) {
      return BiometricFailure.cancelled;
    }
    if (value.contains('biometric-unsupported')) {
      return BiometricFailure.unsupported;
    }
    if (value.contains('biometric-not-enrolled')) {
      return BiometricFailure.notEnrolled;
    }
    if (value.contains('biometric-origin-invalid')) {
      return BiometricFailure.invalidOrigin;
    }
    if (value.contains('biometric-storage-unavailable')) {
      return BiometricFailure.storageUnavailable;
    }
    if (value.contains('biometric-credential-mismatch') ||
        value.contains('biometric-user-mismatch')) {
      return BiometricFailure.credentialMismatch;
    }
    return BiometricFailure.failed;
  }
}

enum BiometricFailure {
  cancelled,
  unsupported,
  notEnrolled,
  invalidOrigin,
  storageUnavailable,
  credentialMismatch,
  failed,
}
