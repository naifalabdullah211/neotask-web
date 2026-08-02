import 'package:flutter_test/flutter_test.dart';
import 'package:neotask_pro/utils/manager_setup_route.dart';

void main() {
  test('root opens manager inauguration while no official manager exists', () {
    expect(
      shouldShowManagerSetup(
        forceLogin: false,
        managerStatusReady: true,
        managerExists: false,
      ),
      isTrue,
    );
  });

  test('/login stays available to existing operational accounts', () {
    expect(
      shouldShowManagerSetup(
        forceLogin: true,
        managerStatusReady: true,
        managerExists: false,
      ),
      isFalse,
    );
  });

  test('inauguration closes after the official manager is created', () {
    expect(
      shouldShowManagerSetup(
        forceLogin: false,
        managerStatusReady: true,
        managerExists: true,
      ),
      isFalse,
    );
  });
}
