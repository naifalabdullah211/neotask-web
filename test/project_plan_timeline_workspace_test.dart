import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:neotask_pro/models/task_model.dart';
import 'package:neotask_pro/theme/app_theme.dart';
import 'package:neotask_pro/widgets/project_plan_timeline_workspace.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  AppTask task({
    required String id,
    required String title,
    required DateTime start,
    required DateTime end,
    int progress = 0,
    String? predecessor,
  }) {
    return AppTask(
      taskId: id,
      title: title,
      description: 'وصف المهمة',
      assignedTo: 'employee-1',
      assignedBy: 'manager-1',
      startDate: start,
      dueDate: end,
      plannedHours: 8,
      progressPercent: progress,
      predecessorTaskIds: predecessor == null ? const [] : [predecessor],
      priority: TaskPriority.high,
      status: progress == 100
          ? TaskStatus.approved
          : TaskStatus.inProgress,
      category: 'التخطيط والتصميم',
      createdAt: start,
      updatedAt: start,
    );
  }

  List<AppTask> sampleTasks() {
    final start = DateTime(2026, 8, 2);
    return [
      task(
        id: 'requirements',
        title: 'تحليل المتطلبات',
        start: start,
        end: start.add(const Duration(days: 4)),
        progress: 100,
      ),
      task(
        id: 'design',
        title: 'تصميم الحل',
        start: start.add(const Duration(days: 5)),
        end: start.add(const Duration(days: 11)),
        progress: 60,
        predecessor: 'requirements',
      ),
    ];
  }

  Widget appFor(Size size) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SizedBox(
            width: size.width,
            height: size.height,
            child: ProjectPlanTimelineWorkspace(
              tasks: sampleTasks(),
              criticalTaskIds: const {'requirements', 'design'},
              readOnly: false,
              onEditTask: (_) {},
              onOpenTask: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders the three-panel desktop workspace without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(appFor(const Size(1440, 850)));
    await tester.pumpAndSettle();

    expect(find.text('الجدول الزمني'), findsOneWidget);
    expect(find.text('تفاصيل المهمة'), findsOneWidget);
    expect(find.text('تحليل المتطلبات'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens task details from the tablet workspace', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(appFor(const Size(900, 800)));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل المهمة'), findsNothing);

    await tester.tap(find.text('تصميم الحل').first);
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل المهمة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the compact task list on mobile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(appFor(const Size(390, 760)));
    await tester.pumpAndSettle();

    expect(find.textContaining('التخطيط والتصميم'), findsOneWidget);
    expect(find.text('تصميم الحل'), findsOneWidget);
    expect(find.text('تفاصيل المهمة'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
