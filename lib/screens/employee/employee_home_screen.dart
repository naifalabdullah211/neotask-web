import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';
import '../../theme/app_theme.dart';
import '../shared/splash_router.dart';
import 'employee_tasks_tab.dart';
import 'employee_calendar_tab.dart';
import 'employee_chat_tab.dart';

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
          const NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
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
