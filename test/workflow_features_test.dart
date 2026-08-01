import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neotask_pro/models/automation_rule_model.dart';
import 'package:neotask_pro/models/custom_form_model.dart';
import 'package:neotask_pro/models/document_model.dart';
import 'package:neotask_pro/models/meeting_model.dart';
import 'package:neotask_pro/models/user_model.dart';
import 'package:neotask_pro/models/voice_call_model.dart';
import 'package:neotask_pro/utils/import_table_parser.dart';

void main() {
  test('voice call signalling round-trips status and SDP safely', () {
    final createdAt = DateTime(2026, 8, 1, 20, 30);
    final call = VoiceCall(
      callId: 'call-1',
      conversationId: 'general-employee-1',
      callerUid: 'manager-1',
      calleeUid: 'employee-1',
      status: VoiceCallStatus.ringing,
      offer: const {'type': 'offer', 'sdp': 'test-sdp'},
      createdAt: createdAt,
    );

    final restored = VoiceCall.fromMap(call.toMap());
    expect(restored.callId, 'call-1');
    expect(restored.status, VoiceCallStatus.ringing);
    expect(restored.offer['type'], 'offer');
    expect(restored.otherParticipant('manager-1'), 'employee-1');
    expect(restored.isTerminal, isFalse);
  });

  test('manager welcome version defaults safely and persists', () {
    final legacy = AppUser.fromMap({
      'uid': 'manager-1',
      'name': 'دكتور محمد الخلاوي',
      'employeeNumber': '1001',
      'role': 'manager',
      'accountStatus': 'active',
      'createdAt': DateTime(2026, 8, 1).toIso8601String(),
    });
    expect(legacy.managerWelcomeVersion, 0);

    final acknowledged = legacy.copyWith(managerWelcomeVersion: 1);
    expect(AppUser.fromMap(acknowledged.toMap()).managerWelcomeVersion, 1);
  });

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

  test('knowledge document preserves workflow, ownership and review data', () {
    final now = DateTime(2026, 8, 1, 12);
    final document = DocumentItem(
      documentId: 'doc-1',
      title: 'سياسة جرد الأدوية المخدرة',
      category: 'سياسات',
      uploadedBy: 'manager-1',
      uploadedByName: 'المدير',
      createdAt: now,
      content: 'يتم الجرد شهريًا',
      kind: DocumentKind.policy,
      department: 'الصيدلية',
      tags: const ['صيدلية', 'JCI'],
      status: DocumentWorkflowStatus.approved,
      version: 3,
      reviewDueDate: DateTime(2027, 8, 1),
    );
    final restored = DocumentItem.fromMap(document.toMap());
    expect(restored.status, DocumentWorkflowStatus.approved);
    expect(restored.kind, DocumentKind.policy);
    expect(restored.version, 3);
    expect(restored.tags, ['صيدلية', 'JCI']);
  });

  test('meeting decision keeps task linkage through serialization', () {
    final now = DateTime(2026, 8, 1, 12);
    final meeting = MeetingItem(
      meetingId: 'meeting-1',
      title: 'اجتماع الجودة',
      description: '',
      startTime: now,
      location: 'قاعة الاجتماعات',
      createdBy: 'manager-1',
      createdByName: 'المدير',
      participantUids: const ['employee-1'],
      createdAt: now,
      agendaItems: const ['مراجعة مؤشرات الأداء'],
      minutes: 'تم اعتماد الإجراء',
      decisions: [
        MeetingDecision(
          decisionId: 'decision-1',
          text: 'تحديث نموذج التدقيق',
          ownerUid: 'employee-1',
          ownerName: 'الموظف',
          dueDate: DateTime(2026, 8, 7),
          linkedTaskId: 'task-1',
          createdAt: now,
        ),
      ],
    );
    final restored = MeetingItem.fromMap(meeting.toMap());
    expect(restored.decisions.single.linkedTaskId, 'task-1');
    expect(restored.agendaItems, ['مراجعة مؤشرات الأداء']);
  });
}
