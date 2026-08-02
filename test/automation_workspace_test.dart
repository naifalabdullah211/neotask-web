import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neotask_pro/models/automation_rule_model.dart';
import 'package:neotask_pro/theme/app_theme.dart';
import 'package:neotask_pro/widgets/automation_workspace.dart';

void main() {
  final now = DateTime(2026, 8, 2, 14, 30);

  AutomationRule rule({
    required String id,
    required String name,
    required bool active,
    required AutomationTrigger trigger,
    required AutomationConditionField field,
    required String condition,
    required AutomationAction action,
    required String actionValue,
  }) => AutomationRule(
    ruleId: id,
    name: name,
    isActive: active,
    trigger: trigger,
    conditionField: field,
    conditionOperator: AutomationOperator.equals,
    conditionValue: condition,
    action: action,
    actionValue: actionValue,
    createdBy: 'manager-1',
    createdAt: now,
    updatedAt: now,
  );

  final rules = [
    rule(
      id: 'overdue',
      name: 'رفع أولوية المهام المتأخرة',
      active: true,
      trigger: AutomationTrigger.overdue,
      field: AutomationConditionField.priority,
      condition: 'medium',
      action: AutomationAction.setPriority,
      actionValue: 'high',
    ),
    rule(
      id: 'review',
      name: 'إشعار المدير عند المراجعة',
      active: false,
      trigger: AutomationTrigger.statusChanged,
      field: AutomationConditionField.status,
      condition: 'submitted',
      action: AutomationAction.notifyManager,
      actionValue: 'مهمة جديدة بانتظار المراجعة',
    ),
  ];

  final runs = [
    AutomationRun(
      runId: 'run-1',
      ruleId: 'overdue',
      ruleName: 'رفع أولوية المهام المتأخرة',
      taskId: 'task-1',
      taskTitle: 'تحديث تقرير الجودة',
      action: 'setPriority',
      status: 'completed',
      executedAt: now,
    ),
  ];

  Widget workspace(Size size) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SizedBox(
          width: size.width,
          height: size.height,
          child: AutomationRulesWorkspace(
            rules: rules,
            runs: runs,
            readOnly: false,
            resolveUserName: (uid) => uid,
            resolveUserPhotoUrl: (_) => null,
            onEdit: (_) {},
            onDuplicate: (_) {},
            onDelete: (_) {},
            onToggle: (_, _) {},
          ),
        ),
      ),
    ),
  );

  testWidgets('renders the three-panel automation workspace on desktop', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(workspace(const Size(1440, 850)));
    await tester.pumpAndSettle();

    expect(find.text('مسار الأتمتة'), findsOneWidget);
    expect(find.text('تفاصيل القاعدة'), findsOneWidget);
    expect(find.text('رفع أولوية المهام المتأخرة'), findsWidgets);
    expect(find.text('الحدث'), findsOneWidget);
    expect(find.text('الشرط'), findsOneWidget);
    expect(find.text('الإجراء'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens rule details from the tablet workspace', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(workspace(const Size(900, 800)));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل القاعدة'), findsNothing);

    await tester.tap(find.text('إشعار المدير عند المراجعة').first);
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل القاعدة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses compact cards and a bottom details sheet on mobile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(workspace(const Size(390, 760)));
    await tester.pumpAndSettle();

    expect(find.text('رفع أولوية المهام المتأخرة'), findsOneWidget);
    expect(find.text('تفاصيل القاعدة'), findsNothing);

    await tester.tap(find.text('رفع أولوية المهام المتأخرة'));
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل القاعدة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('metrics and execution log preserve automation data', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Column(
              children: [
                AutomationMetricsBar(rules: rules, runs: runs),
                Expanded(child: AutomationRunLog(runs: runs)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إجمالي القواعد'), findsOneWidget);
    expect(find.text('نشطة'), findsOneWidget);
    expect(find.text('تحديث تقرير الجودة'), findsOneWidget);
    expect(find.text('ناجح'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
