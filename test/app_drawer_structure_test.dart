import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neotask_pro/screens/shared/app_drawer.dart';

void main() {
  test('shared drawer remains constructible', () {
    expect(const AppDrawer(), isA<Widget>());
  });

  test('drawer keeps the professional information architecture contract', () {
    final source = File(
      'lib/screens/shared/app_drawer.dart',
    ).readAsStringSync();

    for (final section in const [
      'التخطيط والتنفيذ',
      'الإدارة والتواصل',
      'المعرفة والموارد',
    ]) {
      expect(source, contains(section));
    }

    for (final accountAction in const [
      'الإعدادات',
      'المساعدة',
      'تسجيل الخروج',
    ]) {
      expect(source, contains(accountAction));
    }

    for (final destination in const [
      'خطة العمل',
      'الأتمتة الشرطية',
      'التقويم',
      'الأهداف',
      'مهامي الشخصية',
      'التصويت',
      'أفكار المدير',
      'النماذج المخصصة',
      'استيراد Excel / CSV',
      'مركز المعرفة',
      'الاجتماعات',
      'جهات الاتصال',
      'المفضلة',
    ]) {
      expect(source, contains(destination));
    }

    expect(
      source,
      contains('final showManagerTools = isManager || isDesigner'),
    );
    expect(source, contains("fontFamily: 'IBMPlexSansArabic'"));
    expect(source, contains('Semantics('));
    expect(source, contains('selected: isActive'));
  });

  test('manager summary is live, first, compact, and manager-only', () {
    final source = File(
      'lib/screens/shared/app_drawer.dart',
    ).readAsStringSync();

    expect(source, contains('if (isManager && managerStats != null)'));
    expect(source, contains('_DrawerManagerSummary('));
    expect(source, contains('taskProvider.statsForRange(taskProvider.teamTasks)'));
    expect(source, contains('تحديث مباشر لحالة العمل'));
    expect(source, contains('قيد الانتظار'));
    expect(source, contains('بانتظار المراجعة'));
    expect(source, contains('متأخرة'));
    expect(source, contains("label: 'ملخص المدير'"));

    final summaryOffset = source.indexOf('_DrawerManagerSummary(');
    final firstSectionOffset = source.indexOf('_DrawerSection(');
    expect(summaryOffset, greaterThanOrEqualTo(0));
    expect(firstSectionOffset, greaterThan(summaryOffset));
  });
}
