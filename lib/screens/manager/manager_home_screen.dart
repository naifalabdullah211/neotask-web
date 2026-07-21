import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/neo_bottom_nav_bar.dart';
import '../shared/splash_router.dart';
import '../shared/app_drawer.dart';
import 'manager_dashboard_tab.dart';
import 'manager_review_tab.dart';
import 'manager_employees_tab.dart';
import 'manager_reports_tab.dart';
import 'manager_chat_tab.dart';
import 'quick_add_task_sheet.dart';
import '../shared/search_screen.dart';

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
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/neotask_logo.png',
              height: 28,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Text(_titles[_index]),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'بحث',
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
            },
          ),
          NotificationBell(userUid: managerUid),
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
      // Circular quick-add FAB — fixed position (Scaffold.floatingActionButton
      // does not scroll with body content by default). Under this app's
      // forced-RTL Directionality (see main.dart), `endFloat` resolves to
      // the bottom-LEFT corner, matching the explicit RTL requirement.
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _index == 0 || _index == 1
          ? FloatingActionButton(
              backgroundColor: AppColors.mintAccent,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              onPressed: () => QuickAddTaskSheet.show(context),
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: StreamBuilder<List<AppUser>>(
        stream: FirestoreService.watchEmployees(),
        initialData: FirestoreService.getAllEmployees(),
        builder: (context, employeesSnapshot) {
          final pendingEmployees = (employeesSnapshot.data ?? [])
              .where((u) => u.accountStatus == AccountStatus.pendingApproval)
              .length;
          return StreamBuilder<int>(
            stream: context
                .watch<MessageProvider>()
                .watchTotalUnreadCountForUser(managerUid),
            initialData: context
                .read<MessageProvider>()
                .totalUnreadCountForUser(managerUid),
            builder: (context, unreadSnapshot) {
              final unread = unreadSnapshot.data ?? 0;
              return NeoBottomNavBar(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                items: [
                  const NeoNavItem(
                    icon: Icons.dashboard_outlined,
                    selectedIcon: Icons.dashboard,
                    label: 'الرئيسية',
                  ),
                  NeoNavItem(
                    icon: Icons.fact_check_outlined,
                    selectedIcon: Icons.fact_check,
                    label: 'المراجعة',
                    badgeCount: pendingReviewCount,
                  ),
                  NeoNavItem(
                    icon: Icons.groups_outlined,
                    selectedIcon: Icons.groups,
                    label: 'الموظفون',
                    badgeCount: pendingEmployees,
                  ),
                  const NeoNavItem(
                    icon: Icons.bar_chart_outlined,
                    selectedIcon: Icons.bar_chart,
                    label: 'التقارير',
                  ),
                  NeoNavItem(
                    icon: Icons.chat_bubble_outline,
                    selectedIcon: Icons.chat_bubble,
                    label: 'المحادثات',
                    badgeCount: unread,
                  ),
                ],
              );
            },
          );
        },
      ),
      backgroundColor: AppColors.background,
    );
  }
}
