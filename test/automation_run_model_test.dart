import 'package:flutter_test/flutter_test.dart';
import 'package:neotask_pro/models/automation_rule_model.dart';

void main() {
  test('AutomationRun reads execution evidence fields', () {
    final run = AutomationRun.fromMap({
      'runId': 'run-1',
      'ruleId': 'rule-1',
      'ruleName': 'تنبيه الاستحقاق',
      'taskId': 'task-1',
      'taskTitle': 'مراجعة الخطة',
      'action': 'notifyManager',
      'status': 'completed',
      'executedAt': '2026-08-26T10:00:00.000Z',
      'completedAt': '2026-08-26T10:00:00.125Z',
      'durationMs': 125,
      'trigger': 'dueSoon',
      'source': 'cloud-scheduler',
    });

    expect(run.source, 'cloud-scheduler');
    expect(run.trigger, 'dueSoon');
    expect(run.durationMs, 125);
    expect(run.completedAt, DateTime.utc(2026, 8, 26, 10, 0, 0, 125));
  });

  test('AutomationRun remains compatible with old records', () {
    final run = AutomationRun.fromMap({
      'runId': 'legacy',
      'executedAt': '2026-08-26T10:00:00.000Z',
    });

    expect(run.source, isEmpty);
    expect(run.trigger, isEmpty);
    expect(run.durationMs, isNull);
    expect(run.completedAt, isNull);
  });
}
