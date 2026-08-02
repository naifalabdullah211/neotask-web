import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';

void main() {
  const english = Locale('en');
  const arabic = Locale('ar');

  test('Arabic remains the source language and English translates core UI', () {
    expect(AppI18n.translate('الرئيسية', arabic), 'الرئيسية');
    expect(AppI18n.translate('الرئيسية', english), 'Home');
    expect(AppI18n.translate('المراجعة', english), 'Review');
    expect(AppI18n.translate('مساعد NeoTask', english), 'NeoTask Assistant');
    expect(AppI18n.translate('لغة الواجهة', english), 'Interface language');
  });

  test('dynamic system templates translate without changing user content', () {
    expect(
      AppI18n.translate('تم تحويل المهمة إلى Sara', english),
      'Task reassigned to Sara',
    );
    expect(
      AppI18n.translate('5 من 8 مكتمل', english),
      '5 of 8 complete',
    );
    expect(
      AppI18n.translate('Prepare formulary report', english),
      'Prepare formulary report',
    );
    expect(
      AppI18n.translate('مراجعة مخزون الأمبولات', english),
      'مراجعة مخزون الأمبولات',
      reason: 'Unknown user-authored task titles must remain verbatim.',
    );
  });

  test('every material Text screen uses the localized Text adapter', () {
    final roots = [Directory('lib/screens'), Directory('lib/widgets')];
    final missing = <String>[];
    for (final root in roots) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('localized_text.dart') ||
            entity.path.endsWith('language_toggle.dart')) {
          continue;
        }
        final source = entity.readAsStringSync();
        if (!RegExp(r'\bText\(').hasMatch(source)) continue;
        if (!source.contains('localized_text.dart')) missing.add(entity.path);
      }
    }
    expect(missing, isEmpty);
  });

  test('app locale and direction are controlled by LocaleProvider', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('locale: appLocale.locale'));
    expect(source, contains('appLocale.isArabic'));
    expect(source, isNot(contains("locale: const Locale('ar')")));
    expect(source, isNot(contains('textDirection: TextDirection.rtl')));
  });

  test('language controls remain available before and after sign-in', () {
    final login = File('lib/screens/auth/login_screen.dart').readAsStringSync();
    final drawer = File('lib/screens/shared/app_drawer.dart').readAsStringSync();
    final settings = File('lib/screens/shared/settings_screen.dart').readAsStringSync();
    expect(login, contains('LanguageToggle'));
    expect(drawer, contains('LanguageToggle'));
    expect(settings, contains("title: 'لغة الواجهة'"));
  });
}
