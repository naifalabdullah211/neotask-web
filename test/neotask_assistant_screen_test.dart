import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NeoTask assistant is role-aware and explain-only', () {
    final source = File(
      'lib/screens/shared/neotask_assistant_screen.dart',
    ).readAsStringSync();

    expect(source, contains('class NeoTaskAssistantScreen'));
    expect(source, contains('سأوضح وظيفتها وطريقة استخدامها'));
    expect(source, contains('الموضوعات الظاهرة مطابقة لصلاحية حسابك الحالية'));
    expect(source, contains('_HelpAudience.manager'));
    expect(source, contains('_HelpAudience.employee'));
    expect(source, contains('_HelpAudience.managerOrDesigner'));
    expect(source, contains("title: 'وظيفتها'"));
    expect(source, contains("title: 'طريقة الاستخدام'"));
    expect(source, contains("title: 'الصلاحية'"));
    expect(source, contains("title: 'النتيجة'"));
  });

  test('assistant documents the actual primary tabs and drawer entries', () {
    final source = File(
      'lib/screens/shared/neotask_assistant_screen.dart',
    ).readAsStringSync();

    for (final topic in const [
      'ملخص المدير',
      'الرئيسية',
      'المراجعة',
      'الموظفون',
      'التقارير',
      'المحادثات',
      'مهامي',
      'التقويم',
      'خطة العمل',
      'الأتمتة الشرطية',
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
      'الإعدادات',
    ]) {
      expect(source, contains("title: '$topic'"));
    }
  });

  test('drawer opens the real assistant instead of coming-soon feedback', () {
    final drawer = File(
      'lib/screens/shared/app_drawer.dart',
    ).readAsStringSync();

    expect(drawer, contains("import 'neotask_assistant_screen.dart';"));
    expect(drawer, contains('const NeoTaskAssistantScreen()'));
    expect(drawer, isNot(contains("showComingSoon('المساعدة')")));
  });
}
