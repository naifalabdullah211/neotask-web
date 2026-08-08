import 'package:flutter_test/flutter_test.dart';
import 'package:neotask_pro/models/manager_idea_model.dart';

void main() {
  test('manager idea preserves its persisted fields', () {
    final createdAt = DateTime(2026, 8, 1, 9, 30);
    final original = ManagerIdea(
      ideaId: 'idea-1',
      content: 'إضافة تقرير مختصر',
      authorUid: 'manager-1',
      authorName: 'المدير',
      createdAt: createdAt,
    );

    final restored = ManagerIdea.fromMap(original.toMap());

    expect(restored.ideaId, original.ideaId);
    expect(restored.content, original.content);
    expect(restored.authorUid, original.authorUid);
    expect(restored.authorName, original.authorName);
    expect(restored.createdAt, createdAt);
    expect(restored.status, 'new');
    expect(restored.recordType, 'note');
    expect(restored.isTaskRecord, isFalse);
  });

  test('linked assistant record preserves verifiable task metadata', () {
    final createdAt = DateTime(2026, 8, 8, 8, 30);
    final dueDate = DateTime(2026, 8, 10);
    final original = ManagerIdea(
      ideaId: 'task-1',
      content: 'متابعة المهام المتأخرة',
      authorUid: 'manager-1',
      authorName: 'المدير',
      createdAt: createdAt,
      status: 'linked',
      recordType: 'task',
      actionType: 'create_initiative',
      taskId: 'task-1',
      taskTitle: 'مبادرة تحسين المتابعة',
      assigneeUid: 'employee-1',
      assigneeName: 'سارة',
      employeeNumber: '400200',
      dueDate: dueDate,
      priority: 'high',
      plannedHours: 3,
    );

    final restored = ManagerIdea.fromMap(original.toMap());

    expect(restored.isTaskRecord, isTrue);
    expect(restored.taskId, 'task-1');
    expect(restored.assigneeName, 'سارة');
    expect(restored.employeeNumber, '400200');
    expect(restored.dueDate, dueDate);
    expect(restored.priority, 'high');
    expect(restored.plannedHours, 3);
  });

  test('legacy rule removes repeated heading from display details', () {
    final record = ManagerIdea(
      ideaId: 'legacy-rule',
      content: 'قاعدة دائمة للوكيل: تنبيه الفريق\nتنبيه الفريق',
      authorUid: 'manager-1',
      authorName: 'المدير',
      createdAt: DateTime(2026, 8, 8),
    );

    expect(record.isRuleRecord, isTrue);
    expect(record.displayTitle, 'تنبيه الفريق');
    expect(record.displayDetails, isEmpty);
  });

  test('typed assistant records expose their category and clean content', () {
    final rule = ManagerIdea(
      ideaId: 'rule-record',
      content: 'أرسل تنبيهًا عند تأخر المهمة',
      authorUid: 'manager-1',
      authorName: 'المدير',
      createdAt: DateTime(2026, 8, 8),
      recordType: 'rule',
      actionType: 'update_agent_rule',
      recordTitle: 'تنبيه المهام المتأخرة',
      ruleId: 'rule-1',
    );
    final analysis = ManagerIdea(
      ideaId: 'analysis-record',
      content: 'ثلاث مهام متأخرة هذا الأسبوع',
      authorUid: 'manager-1',
      authorName: 'المدير',
      createdAt: DateTime(2026, 8, 8),
      recordType: 'analysis',
      actionType: 'team_summary',
      recordTitle: 'ملخص أداء الفريق',
    );

    expect(rule.isRuleRecord, isTrue);
    expect(rule.hasLinkedRule, isTrue);
    expect(rule.displayTitle, 'تنبيه المهام المتأخرة');
    expect(rule.displayDetails, 'أرسل تنبيهًا عند تأخر المهمة');
    expect(analysis.isAnalysisRecord, isTrue);
    expect(analysis.displayTitle, 'ملخص أداء الفريق');
  });
}
