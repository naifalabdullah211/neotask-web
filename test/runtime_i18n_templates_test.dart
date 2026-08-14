import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';

void main() {
  const english = Locale('en');

  test('runtime workspace counters translate fully to English', () {
    expect(AppI18n.translate('5 قاعدة', english), '5 rules');
    expect(AppI18n.translate('3 هدف في العرض', english), '3 goals in view');
    expect(AppI18n.translate('4 تصويت في العرض', english), '4 polls in view');
    expect(AppI18n.translate('7 مهمة في العرض', english), '7 tasks in view');
    expect(AppI18n.translate('2/6 معايير', english), '2/6 criteria');
    expect(
      AppI18n.translate('أحداث الشهر الحالي (9)', english),
      'Current month events (9)',
    );
  });

  test('runtime system notes preserve user data while translating chrome', () {
    expect(
      AppI18n.translate('ملاحظة المدير: Follow supplier', english),
      'Manager note: Follow supplier',
    );
    expect(
      AppI18n.translate('سبب الرفض: Missing attachment', english),
      'Rejection reason: Missing attachment',
    );
    expect(
      AppI18n.translate('الملف: stock.xlsx', english),
      'File: stock.xlsx',
    );
    expect(
      AppI18n.translate('Quarter Review - نسخة', english),
      'Quarter Review - Copy',
    );
  });

  test('runtime workflow feedback translates to English', () {
    expect(
      AppI18n.translate('تم تحديث الحالة إلى مكتملة', english),
      'Status updated to Completed',
    );
    expect(
      AppI18n.translate('تعذّر بدء التسجيل: permission denied', english),
      'Could not start recording: permission denied',
    );
    expect(
      AppI18n.translate('عدد المهام في هذا النطاق: 12', english),
      'Tasks in this range: 12',
    );
  });

  test('Arabic mode keeps the source copy unchanged', () {
    const arabic = Locale('ar');
    expect(AppI18n.translate('5 قاعدة', arabic), '5 قاعدة');
    expect(
      AppI18n.translate('ملاحظة المدير: متابعة', arabic),
      'ملاحظة المدير: متابعة',
    );
  });
}
