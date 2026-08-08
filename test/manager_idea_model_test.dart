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
}
