import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/neo_bottom_nav_bar.dart';
import '../manager/luxury_manager_dashboard.dart';
import '../manager/manager_home_screen.dart';
import '../manager/manager_reports_tab.dart';
import '../manager/manager_review_tab.dart';
import '../shared/app_drawer.dart';
import 'designer_chat_tab.dart';
import 'designer_employees_tab.dart';

/// The observer sees the complete premium NeoTask workspace used by the
/// manager, while every action surface is replaced with a read-only view.
class DesignerHomeScreen extends StatefulWidget {
  const DesignerHomeScreen({super.key});

  @override
  State<DesignerHomeScreen> createState() => _DesignerHomeScreenState();
}

class _DesignerHomeScreenState extends State<DesignerHomeScreen> {
  int _index = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final observer = context.watch<AuthProvider>().currentUser!;
    final pendingReviewCount = context
        .watch<TaskProvider>()
        .submittedForReview
        .length;
    final desktop = MediaQuery.sizeOf(context).width >= 960;

    final pages = [
      const LuxuryManagerDashboard(readOnly: true),
      const ManagerReviewTab(readOnly: true),
      const DesignerEmployeesTab(),
      const ManagerReportsTab(readOnly: true),
      DesignerChatTab(designerUid: observer.uid),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          LuxuryTopNav(
            desktop: desktop,
            selectedIndex: _index,
            manager: observer,
            roleLabel: 'متابعة · عرض فقط',
            onTabSelected: (index) => setState(() => _index = index),
            onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          Expanded(child: IndexedStack(index: _index, children: pages)),
        ],
      ),
      bottomNavigationBar: desktop
          ? null
          : NeoBottomNavBar(
              selectedIndex: _index,
              onDestinationSelected: (index) =>
                  setState(() => _index = index),
              items: [
                const NeoNavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: 'الرئيسية',
                ),
                NeoNavItem(
                  icon: Icons.fact_check_outlined,
                  selectedIcon: Icons.fact_check,
                  label: 'المراجعة',
                  badgeCount: pendingReviewCount,
                ),
                const NeoNavItem(
                  icon: Icons.groups_outlined,
                  selectedIcon: Icons.groups,
                  label: 'الموظفون',
                ),
                const NeoNavItem(
                  icon: Icons.bar_chart_outlined,
                  selectedIcon: Icons.bar_chart,
                  label: 'التقارير',
                ),
                const NeoNavItem(
                  icon: Icons.chat_bubble_outline,
                  selectedIcon: Icons.chat_bubble,
                  label: 'المحادثات',
                ),
              ],
            ),
    );
  }
}
