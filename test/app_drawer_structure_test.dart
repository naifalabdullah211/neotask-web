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
}
