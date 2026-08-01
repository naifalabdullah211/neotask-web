import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/neo_bottom_nav_bar.dart';
import '../shared/splash_router.dart';
import '../shared/app_drawer.dart';
import 'employee_tasks_tab.dart';
import 'employee_calendar_tab.dart';
import 'employee_chat_tab.dart';
import 'employee_polls_tab.dart';
import '../shared/search_screen.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  int _index = 0;

  static const _titles = ['مهامي', 'التقويم', 'المحادثة', 'تصويت'];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final employeeUid = auth.currentUser!.uid;
    final unviewedTasks = context
        .watch<TaskProvider>()
        .unviewedTaskCountForEmployee(employeeUid);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/neotask_brand_mark.png',
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
          NotificationBell(userUid: employeeUid),
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
      body: IndexedStack(
        index: _index,
        children: [
          EmployeeTasksTab(employeeUid: employeeUid),
          EmployeeCalendarTab(employeeUid: employeeUid),
          EmployeeChatTab(employeeUid: employeeUid),
          EmployeePollsTab(employeeUid: employeeUid),
        ],
      ),
      bottomNavigationBar: StreamBuilder<int>(
        stream: context.watch<MessageProvider>().watchTotalUnreadCountForUser(
          employeeUid,
        ),
        initialData: context.read<MessageProvider>().totalUnreadCountForUser(
          employeeUid,
        ),
        builder: (context, snapshot) {
          final unread = snapshot.data ?? 0;
          return NeoBottomNavBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            items: [
              NeoNavItem(
                icon: Icons.checklist_outlined,
                selectedIcon: Icons.checklist,
                label: 'مهامي',
                badgeCount: unviewedTasks,
              ),
              const NeoNavItem(
                icon: Icons.calendar_month_outlined,
                selectedIcon: Icons.calendar_month,
                label: 'التقويم',
              ),
              NeoNavItem(
                icon: Icons.chat_bubble_outline,
                selectedIcon: Icons.chat_bubble,
                label: 'المحادثة',
                badgeCount: unread,
              ),
              const NeoNavItem(
                icon: Icons.how_to_vote_outlined,
                selectedIcon: Icons.how_to_vote,
                label: 'تصويت',
              ),
            ],
          );
        },
      ),
      backgroundColor: AppColors.background,
    );
  }
}
