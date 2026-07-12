import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';
import '../shared/splash_router.dart';
import '../shared/app_drawer.dart';
import 'employee_tasks_tab.dart';
import 'employee_calendar_tab.dart';
import 'employee_chat_tab.dart';
import '../shared/search_screen.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  int _index = 0;

  static const _titles = ['مهامي', 'التقويم', 'المحادثة'];

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
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
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
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unviewedTasks > 0,
              label: Text('$unviewedTasks'),
              child: const Icon(Icons.checklist_outlined),
            ),
            selectedIcon: const Icon(Icons.checklist),
            label: 'مهامي',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'التقويم',
          ),
          StreamBuilder<int>(
            stream: context
                .watch<MessageProvider>()
                .watchTotalUnreadCountForUser(employeeUid),
            initialData: context
                .read<MessageProvider>()
                .totalUnreadCountForUser(employeeUid),
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;
              return NavigationDestination(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.chat_bubble_outline),
                ),
                selectedIcon: const Icon(Icons.chat_bubble),
                label: 'المحادثة',
              );
            },
          ),
        ],
      ),
      backgroundColor: AppColors.background,
    );
  }
}
