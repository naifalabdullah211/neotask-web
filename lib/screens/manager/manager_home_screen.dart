import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../shared/splash_router.dart';
import 'manager_dashboard_tab.dart';
import 'manager_review_tab.dart';
import 'manager_employees_tab.dart';
import 'manager_reports_tab.dart';
import 'manager_chat_tab.dart';
import 'manager_create_task_screen.dart';

class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key});

  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  int _index = 0;

  static const _titles = [
    'لوحة التحكم',
    'مراجعة المهام',
    'الموظفون',
    'التقارير',
    'المحادثات',
  ];

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final pendingReviewCount = taskProvider.submittedForReview.length;
    final auth = context.watch<AuthProvider>();
    final managerUid = auth.currentUser!.uid;

    final pages = [
      const ManagerDashboardTab(),
      const ManagerReviewTab(),
      const ManagerEmployeesTab(),
      const ManagerReportsTab(),
      ManagerChatTab(managerUid: managerUid),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashRouter()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: _index == 0 || _index == 1
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ManagerCreateTaskScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_task),
              label: const Text('مهمة جديدة'),
            )
          : null,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pendingReviewCount > 0,
              label: Text('$pendingReviewCount'),
              child: const Icon(Icons.fact_check_outlined),
            ),
            selectedIcon: const Icon(Icons.fact_check),
            label: 'المراجعة',
          ),
          StreamBuilder<List<AppUser>>(
            stream: FirestoreService.watchEmployees(),
            initialData: FirestoreService.getAllEmployees(),
            builder: (context, snapshot) {
              final pendingEmployees = (snapshot.data ?? [])
                  .where(
                    (u) => u.accountStatus == AccountStatus.pendingApproval,
                  )
                  .length;
              return NavigationDestination(
                icon: Badge(
                  isLabelVisible: pendingEmployees > 0,
                  label: Text('$pendingEmployees'),
                  child: const Icon(Icons.groups_outlined),
                ),
                selectedIcon: const Icon(Icons.groups),
                label: 'الموظفون',
              );
            },
          ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'التقارير',
          ),
          StreamBuilder<int>(
            stream: context
                .watch<MessageProvider>()
                .watchTotalUnreadCountForUser(managerUid),
            initialData: context
                .read<MessageProvider>()
                .totalUnreadCountForUser(managerUid),
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;
              return NavigationDestination(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.chat_bubble_outline),
                ),
                selectedIcon: const Icon(Icons.chat_bubble),
                label: 'المحادثات',
              );
            },
          ),
        ],
      ),
      backgroundColor: AppColors.background,
    );
  }
}
