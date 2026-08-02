import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neotask_pro/models/poll_model.dart';
import 'package:neotask_pro/models/task_model.dart';
import 'package:neotask_pro/screens/manager/manager_calendar_screen.dart';
import 'package:neotask_pro/screens/manager/manager_my_tasks_screen.dart';
import 'package:neotask_pro/screens/manager/manager_polls_tab.dart';
import 'package:neotask_pro/screens/shared/goals_list_screen.dart';
import 'package:neotask_pro/theme/app_theme.dart';
import 'package:neotask_pro/widgets/personal_tasks_workspace.dart';
import 'package:neotask_pro/widgets/polls_workspace.dart';

void main() {
  final now = DateTime(2026, 8, 2, 12);

  AppTask personalTask({
    required String id,
    required String title,
    required TaskStatus status,
    required DateTime dueDate,
  }) {
    return AppTask(
      taskId: id,
      title: title,
      description: 'وصف شخصي',
      assignedTo: 'manager-1',
      assignedBy: 'manager-1',
      dueDate: dueDate,
      priority: TaskPriority.high,
      status: status,
      category: 'متابعة شخصية',
      createdAt: now,
      updatedAt: now,
    );
  }

  final personalTasks = [
    personalTask(
      id: 'focus',
      title: 'مراجعة خطة القسم',
      status: TaskStatus.inProgress,
      dueDate: now.add(const Duration(days: 1)),
    ),
    personalTask(
      id: 'done',
      title: 'اعتماد المحضر',
      status: TaskStatus.approved,
      dueDate: now.subtract(const Duration(days: 1)),
    ),
  ];

  final polls = [
    AppPoll(
      pollId: 'active',
      title: 'اختيار موعد الاجتماع',
      description: 'حدد الموعد الأنسب للفريق',
      choices: const ['الأحد', 'الثلاثاء', 'الخميس'],
      participantUids: const ['e1', 'e2', 'e3'],
      createdBy: 'manager-1',
      deadline: now.add(const Duration(days: 3)),
      createdAt: now,
      status: PollStatus.active,
    ),
    AppPoll(
      pollId: 'ended',
      title: 'اختيار برنامج التدريب',
      description: 'تصويت منتهي',
      choices: const ['الخيار الأول', 'الخيار الثاني'],
      participantUids: const ['e1', 'e2'],
      createdBy: 'manager-1',
      deadline: now.subtract(const Duration(days: 2)),
      createdAt: now.subtract(const Duration(days: 4)),
      status: PollStatus.ended,
      choiceCounts: const [2, 0],
    ),
  ];

  Widget personalApp(Size size) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SizedBox(
          width: size.width,
          height: size.height,
          child: PersonalTasksWorkspace(
            tasks: personalTasks,
            readOnly: false,
            onToggleDone: (_, __) async {},
            onOpen: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    ),
  );

  Widget pollsApp(Size size) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SizedBox(
          width: size.width,
          height: size.height,
          child: PollsWorkspace(polls: polls, onOpenPoll: (_) {}),
        ),
      ),
    ),
  );

  testWidgets('personal tasks render as a three-panel desktop workspace', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(personalApp(const Size(1440, 850)));
    await tester.pumpAndSettle();

    expect(find.text('قائمة التركيز'), findsOneWidget);
    expect(find.text('تفاصيل المهمة'), findsOneWidget);
    expect(find.text('مراجعة خطة القسم'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('personal task details open from the compact mobile list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(personalApp(const Size(390, 760)));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل المهمة'), findsNothing);

    await tester.tap(find.text('مراجعة خطة القسم'));
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل المهمة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('polls render the decision canvas and desktop details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(pollsApp(const Size(1440, 850)));
    await tester.pumpAndSettle();

    expect(find.text('موضوعات التصويت'), findsOneWidget);
    expect(find.text('خيارات القرار'), findsOneWidget);
    expect(find.text('تفاصيل التصويت'), findsOneWidget);
    expect(find.text('اختيار موعد الاجتماع'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('poll details open from the mobile list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(pollsApp(const Size(390, 760)));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل التصويت'), findsNothing);

    await tester.tap(find.text('اختيار موعد الاجتماع'));
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل التصويت'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('all redesigned top-level screens remain constructible', () {
    expect(const ManagerCalendarScreen(), isA<Widget>());
    expect(const GoalsListScreen(), isA<Widget>());
    expect(const ManagerMyTasksScreen(), isA<Widget>());
    expect(const ManagerPollsTab(), isA<Widget>());
  });
}
