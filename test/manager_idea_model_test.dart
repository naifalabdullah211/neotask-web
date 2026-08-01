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
  });
}
