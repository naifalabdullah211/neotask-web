import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manager summary appears in drawer only, not on home dashboards', () {
    final drawer = File('lib/screens/shared/app_drawer.dart').readAsStringSync();
    final modernHome = File(
      'lib/screens/manager/luxury_manager_dashboard.dart',
    ).readAsStringSync();
    final classicHome = File(
      'lib/screens/manager/manager_dashboard_tab.dart',
    ).readAsStringSync();

    expect(drawer, contains('_DrawerManagerSummary('));
    expect(modernHome, isNot(contains('DailyDigestCard(')));
    expect(classicHome, isNot(contains('DailyDigestCard(')));
  });
}
