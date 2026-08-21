// ignore_for_file: deprecated_member_use

import 'dart:html' as html;
import 'dart:js_util' as js_util;

Object _api() {
  final api = js_util.getProperty<Object?>(
    html.window,
    'neoTaskBiometrics',
  );
  if (api == null) throw StateError('biometric-unsupported');
  return api;
}

Future<T> _call<T>(String method, [List<Object?> arguments = const []]) {
  final promise = js_util.callMethod<Object>(_api(), method, arguments);
  return js_util.promiseToFuture<T>(promise);
}

Future<bool> isSupported() async {
  try {
    return await _call<bool>('isSupported');
  } catch (_) {
    return false;
  }
}

Future<bool> isEnabled(String uid) async {
  try {
    return await _call<bool>('isEnabled', [uid]);
  } catch (_) {
    return false;
  }
}

Future<bool> shouldOfferEnrollment(String uid) async {
  try {
    return await _call<bool>('shouldOfferEnrollment', [uid]);
  } catch (_) {
    return false;
  }
}

Future<void> dismissEnrollmentOffer(String uid) async {
  try {
    await _call<bool>('dismissEnrollmentOffer', [uid]);
  } catch (_) {
    // The optional first-use offer must never block the signed-in app.
  }
}

Future<void> enroll({
  required String uid,
  required String employeeNumber,
  required String displayName,
}) async {
  await _call<bool>('enroll', [uid, employeeNumber, displayName]);
}

Future<void> unlock(String uid) async {
  await _call<bool>('unlock', [uid]);
}

Future<void> disable(String uid) async {
  await _call<bool>('disable', [uid]);
}

Future<void> markInteractiveLogin(String uid) async {
  try {
    await _call<bool>('markInteractiveLogin', [uid]);
  } catch (_) {
    // This one-navigation marker is best-effort. A missing/stale bridge must
    // never strand a user after Firebase has already accepted the password.
  }
}

Future<bool> consumeInteractiveLogin(String uid) async {
  try {
    return await _call<bool>('consumeInteractiveLogin', [uid]);
  } catch (_) {
    return false;
  }
}
