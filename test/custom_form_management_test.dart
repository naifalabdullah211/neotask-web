import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('custom forms expose whole-form edit and delete actions', () {
    final screen = File(
      'lib/screens/manager/custom_forms_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('تعديل النموذج'));
    expect(screen, contains('حذف النموذج'));
    expect(screen, contains('حذف النموذج بالكامل'));
    expect(screen, contains('جميع الردود المرتبطة به نهائيًا'));
    expect(screen, contains('if (!readOnly)'));
  });

  test('form deletion removes responses before the parent document', () {
    final service = File(
      'lib/services/workflow_service.dart',
    ).readAsStringSync();
    final deleteMethod = service.substring(
      service.indexOf('static Future<void> deleteForm'),
      service.indexOf(
        'static Stream<List<CustomFormResponse>> watchFormResponses',
      ),
    );

    expect(deleteMethod, contains("collection('responses')"));
    expect(deleteMethod, contains('limit(400)'));
    expect(deleteMethod, contains('batch.delete(response.reference)'));
    expect(
      deleteMethod.indexOf('await batch.commit()'),
      lessThan(deleteMethod.indexOf('await formRef.delete()')),
    );
  });

  test('Firestore rules authorize manager-only form deletion', () {
    final rules = File('firestore.rules').readAsStringSync();
    final customForms = rules.substring(
      rules.indexOf('match /custom_forms/{formId}'),
      rules.indexOf('match /import_jobs/{jobId}'),
    );

    expect(
      RegExp(r'allow delete: if isManager\(\);')
          .allMatches(customForms)
          .length,
      2,
    );
  });
}
