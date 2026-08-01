enum AutomationTrigger { taskCreated, statusChanged, dueSoon, overdue }

enum AutomationConditionField { any, status, priority, category, assignee, progress }

enum AutomationOperator { equals, contains, greaterOrEqual }

enum AutomationAction { notifyAssignee, notifyManager, setPriority, reassign }

class AutomationRule {
  const AutomationRule({
    required this.ruleId,
    required this.name,
    required this.isActive,
    required this.trigger,
    required this.conditionField,
    required this.conditionOperator,
    required this.conditionValue,
    required this.action,
    required this.actionValue,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.dueWithinHours = 24,
  });

  final String ruleId;
  final String name;
  final bool isActive;
  final AutomationTrigger trigger;
  final AutomationConditionField conditionField;
  final AutomationOperator conditionOperator;
  final String conditionValue;
  final AutomationAction action;
  final String actionValue;
  final int dueWithinHours;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
    'ruleId': ruleId,
    'name': name,
    'isActive': isActive,
    'trigger': trigger.name,
    'conditionField': conditionField.name,
    'conditionOperator': conditionOperator.name,
    'conditionValue': conditionValue,
    'action': action.name,
    'actionValue': actionValue,
    'dueWithinHours': dueWithinHours,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory AutomationRule.fromMap(Map<String, dynamic> map) {
    T enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
      return values.where((value) => value.name == raw).firstOrNull ?? fallback;
    }

    return AutomationRule(
      ruleId: map['ruleId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? false,
      trigger: enumValue(
        AutomationTrigger.values,
        map['trigger'],
        AutomationTrigger.taskCreated,
      ),
      conditionField: enumValue(
        AutomationConditionField.values,
        map['conditionField'],
        AutomationConditionField.any,
      ),
      conditionOperator: enumValue(
        AutomationOperator.values,
        map['conditionOperator'],
        AutomationOperator.equals,
      ),
      conditionValue: map['conditionValue'] as String? ?? '',
      action: enumValue(
        AutomationAction.values,
        map['action'],
        AutomationAction.notifyAssignee,
      ),
      actionValue: map['actionValue'] as String? ?? '',
      dueWithinHours: (map['dueWithinHours'] as num?)?.toInt() ?? 24,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class AutomationRun {
  const AutomationRun({
    required this.runId,
    required this.ruleId,
    required this.ruleName,
    required this.taskId,
    required this.taskTitle,
    required this.action,
    required this.status,
    required this.executedAt,
    this.message,
  });

  final String runId;
  final String ruleId;
  final String ruleName;
  final String taskId;
  final String taskTitle;
  final String action;
  final String status;
  final DateTime executedAt;
  final String? message;

  factory AutomationRun.fromMap(Map<String, dynamic> map) => AutomationRun(
    runId: map['runId'] as String? ?? '',
    ruleId: map['ruleId'] as String? ?? '',
    ruleName: map['ruleName'] as String? ?? '',
    taskId: map['taskId'] as String? ?? '',
    taskTitle: map['taskTitle'] as String? ?? '',
    action: map['action'] as String? ?? '',
    status: map['status'] as String? ?? '',
    executedAt: DateTime.tryParse(map['executedAt'] as String? ?? '') ??
        DateTime.now(),
    message: map['message'] as String?,
  );
}
