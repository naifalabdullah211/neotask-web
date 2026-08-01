import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neo_bottom_nav_bar.dart';
import '../shared/splash_router.dart';
import '../shared/app_drawer.dart';
import 'designer_dashboard_tab.dart';
import 'designer_employees_tab.dart';
import 'designer_chat_tab.dart';

/// Home shell for the `designer` read-only observer role (see
/// UserRole.designer doc comment in user_model.dart for the full
/// 1-a/2-a/3-no design rationale this entire screen implements).
///
/// Deliberately mirrors ManagerHomeScreen's shell structure (AppDrawer +
/// AppBar + IndexedStack + bottom NavigationBar) so the designer sees a
/// layout consistent with the rest of the app, but:
///   - NO floating action button anywhere (no "مهمة جديدة" — 3-no).
///   - NO search entry point in the AppBar (SearchScreen's
///     `_TaskResultTile` is not yet role-aware and would route into
///     TaskDetailScreen, which has write-looking buttons not gated by
///     assignee ownership — omitting the entry point here avoids that
///     gap entirely until it is fixed).
///   - Bottom nav has exactly 3 read-only tabs: dashboard, employees,
///     conversations. Review/Reports tabs are intentionally NOT included
///     (Reports' PDF export is a local-file action, not yet decided
///     whether to expose; Review tab only exists to expose
///     approve/reject actions, which must never be shown to a designer).
class DesignerHomeScreen extends StatefulWidget {
  const DesignerHomeScreen({super.key});

  @override
  State<DesignerHomeScreen> createState() => _DesignerHomeScreenState();
}

class _DesignerHomeScreenState extends State<DesignerHomeScreen> {
  int _index = 0;

  static const _titles = ['لوحة التحكم', 'الموظفون', 'المحادثات'];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final designerUid = auth.currentUser!.uid;

    final pages = [
      const DesignerDashboardTab(),
      const DesignerEmployeesTab(),
      DesignerChatTab(designerUid: designerUid),
    ];

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
      // No floatingActionButton — 3-no: absolute zero write access.
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NeoBottomNavBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        items: const [
          NeoNavItem(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            label: 'الرئيسية',
          ),
          NeoNavItem(
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups,
            label: 'الموظفون',
          ),
          NeoNavItem(
            icon: Icons.chat_bubble_outline,
            selectedIcon: Icons.chat_bubble,
            label: 'المحادثات',
          ),
        ],
      ),
      backgroundColor: AppColors.background,
    );
  }
}
