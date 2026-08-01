import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neotask_pro/models/automation_rule_model.dart';
import 'package:neotask_pro/models/custom_form_model.dart';
import 'package:neotask_pro/utils/import_table_parser.dart';

void main() {
  test('automation rule persists every executable setting', () {
    final now = DateTime(2026, 8, 1, 12);
    final rule = AutomationRule(
      ruleId: 'rule-1',
      name: 'رفع أولوية المتأخر',
      isActive: true,
      trigger: AutomationTrigger.overdue,
      conditionField: AutomationConditionField.category,
      conditionOperator: AutomationOperator.contains,
      conditionValue: 'جودة',
      action: AutomationAction.setPriority,
      actionValue: 'high',
      dueWithinHours: 24,
      createdBy: 'manager',
      createdAt: now,
      updatedAt: now,
    );
    final restored = AutomationRule.fromMap(rule.toMap());
    expect(restored.trigger, AutomationTrigger.overdue);
    expect(restored.conditionField, AutomationConditionField.category);
    expect(restored.action, AutomationAction.setPriority);
    expect(restored.actionValue, 'high');
  });

  test('custom form preserves ordered required fields and choices', () {
    final now = DateTime(2026, 8, 1);
    final form = CustomFormDefinition(
      formId: 'form-1',
      title: 'طلب خدمة',
      description: '',
      isActive: true,
      fields: const [
        CustomFormField(
          fieldId: 'name',
          label: 'الاسم',
          type: CustomFieldType.shortText,
          isRequired: true,
        ),
        CustomFormField(
          fieldId: 'type',
          label: 'نوع الطلب',
          type: CustomFieldType.choice,
          isRequired: true,
          options: ['عاجل', 'عادي'],
        ),
      ],
      createdBy: 'manager',
      createdAt: now,
      updatedAt: now,
    );
    final restored = CustomFormDefinition.fromMap(form.toMap());
    expect(restored.fields.map((field) => field.fieldId), ['name', 'type']);
    expect(restored.fields.last.options, ['عاجل', 'عادي']);
  });

  test('CSV parser accepts Arabic headers, UTF-8, and quoted commas', () {
    const csv = 'الاسم,الرقم الوظيفي,كلمة المرور\n"نايف, عبدالله",1001,secret1\n';
    final table = ImportTableParser.parse(
      fileName: 'employees.csv',
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
    expect(table.headers, ['name', 'employeeNumber', 'password']);
    expect(table.rows.single['name'], 'نايف, عبدالله');
    expect(table.rows.single['employeeNumber'], '1001');
  });
}
