Future<bool> isSupported() async => false;

Future<bool> isEnabled(String uid) async => false;

Future<bool> shouldOfferEnrollment(String uid) async => false;

Future<void> dismissEnrollmentOffer(String uid) async {}

Future<void> enroll({
  required String uid,
  required String employeeNumber,
  required String displayName,
}) async {
  throw UnsupportedError('biometric-unsupported');
}

Future<void> unlock(String uid) async {
  throw UnsupportedError('biometric-unsupported');
}

Future<void> disable(String uid) async {}

Future<void> markInteractiveLogin(String uid) async {}

Future<bool> consumeInteractiveLogin(String uid) async => false;
