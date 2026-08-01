import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/interface_style_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/neo_bottom_nav_bar.dart';
import '../../widgets/user_avatar.dart';
import '../shared/splash_router.dart';
import '../shared/app_drawer.dart';
import 'manager_dashboard_tab.dart';
import 'manager_review_tab.dart';
import 'manager_employees_tab.dart';
import 'manager_reports_tab.dart';
import 'manager_chat_tab.dart';
import 'quick_add_task_sheet.dart';
import 'luxury_manager_dashboard.dart';
import 'manager_ideas_screen.dart';
import '../shared/search_screen.dart';

class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key});

  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  int _index = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _titles = [
    'لوحة التحكم',
    'مراجعة المهام',
    'الموظفون',
    'التقارير',
    'المحادثات',
  ];

  @override
  Widget build(BuildContext context) {
    final interfaceStyle = context.watch<InterfaceStyleProvider>();
    if (interfaceStyle.isModern) {
      return _buildLuxury(context);
    }
    return _buildClassic(context);
  }

  Widget _buildLuxury(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final pendingReviewCount = taskProvider.submittedForReview.length;
    final auth = context.watch<AuthProvider>();
    final manager = auth.currentUser!;
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 960;

    final pages = [
      const LuxuryManagerDashboard(),
      const ManagerReviewTab(),
      const ManagerEmployeesTab(),
      const ManagerReportsTab(),
      ManagerChatTab(managerUid: manager.uid),
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
            manager: manager,
            onTabSelected: (index) => setState(() => _index = index),
            onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
            onOpenIdeas: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ManagerIdeasScreen(manager: manager),
              ),
            ),
            onOpenSearch: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          Expanded(
            child: IndexedStack(index: _index, children: pages),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: !desktop && (_index == 0 || _index == 1)
          ? FloatingActionButton(
              backgroundColor: AppColors.mintAccent,
              foregroundColor: const Color(0xFF071D3B),
              shape: const CircleBorder(),
              onPressed: () => QuickAddTaskSheet.show(context),
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      bottomNavigationBar: desktop
          ? null
          : StreamBuilder<List<AppUser>>(
              stream: FirestoreService.watchEmployees(),
              initialData: FirestoreService.getAllEmployees(),
              builder: (context, employeesSnapshot) {
                final pendingEmployees = (employeesSnapshot.data ?? [])
                    .where(
                      (user) =>
                          user.accountStatus == AccountStatus.pendingApproval,
                    )
                    .length;
                return StreamBuilder<int>(
                  stream: context
                      .watch<MessageProvider>()
                      .watchTotalUnreadCountForUser(manager.uid),
                  initialData: context
                      .read<MessageProvider>()
                      .totalUnreadCountForUser(manager.uid),
                  builder: (context, unreadSnapshot) {
                    return NeoBottomNavBar(
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
                          badgeCount: unreadSnapshot.data ?? 0,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildClassic(BuildContext context) {
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

class LuxuryTopNav extends StatelessWidget {
  const LuxuryTopNav({
    required this.desktop,
    required this.selectedIndex,
    required this.manager,
    required this.onTabSelected,
    required this.onOpenMenu,
    required this.onOpenIdeas,
    required this.onOpenSearch,
    this.roleLabel = 'مدير القسم',
  });

  final bool desktop;
  final int selectedIndex;
  final AppUser manager;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onOpenMenu;
  final VoidCallback onOpenIdeas;
  final VoidCallback onOpenSearch;
  final String roleLabel;

  static const _labels = [
    'الرئيسية',
    'المراجعة',
    'الموظفون',
    'التقارير',
    'المحادثات',
  ];

  @override
  Widget build(BuildContext context) {
    if (!desktop) {
      return Container(
        height: 82,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: const BoxDecoration(
          color: Color(0xFF071D3B),
          border: Border(
            bottom: BorderSide(color: Color(0x99E6AD36), width: 0.8),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              _HeaderAccount(
                manager: manager,
                onTap: onOpenMenu,
                compact: true,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'بحث شامل',
                onPressed: onOpenSearch,
                color: Colors.white,
                icon: const Icon(Icons.search, size: 25),
              ),
              const SizedBox(width: 3),
              IconButton(
                tooltip: 'أفكار المدير',
                onPressed: onOpenIdeas,
                color: const Color(0xFFE6AD36),
                icon: const Icon(Icons.lightbulb_outline, size: 25),
              ),
              const SizedBox(width: 3),
              const _HeaderBrand(compact: true),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 104,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Color(0xFF071D3B),
        border: Border(
          bottom: BorderSide(color: Color(0x99E6AD36), width: 0.8),
        ),
      ),
      child: Row(
        children: [
          _HeaderAccount(
            manager: manager,
            onTap: onOpenMenu,
            roleLabel: roleLabel,
          ),
          Container(
            width: 1,
            height: 46,
            color: Colors.white.withValues(alpha: 0.18),
          ),
          const SizedBox(width: 26),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < _labels.length; i++) ...[
                                if (i > 0) const SizedBox(width: 10),
                                _DesktopNavButton(
                                  label: _labels[i],
                                  selected: selectedIndex == i,
                                  onTap: () => onTabSelected(i),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 28),
          IconButton(
            tooltip: 'بحث شامل',
            onPressed: onOpenSearch,
            color: Colors.white,
            icon: const Icon(Icons.search, size: 27),
          ),
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            width: 1,
            color: Colors.white.withValues(alpha: 0.20),
          ),
          IconButton(
            tooltip: 'أفكار المدير',
            onPressed: onOpenIdeas,
            color: const Color(0xFFE6AD36),
            icon: const Icon(Icons.lightbulb_outline, size: 27),
          ),
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            width: 1,
            color: Colors.white.withValues(alpha: 0.20),
          ),
          IconTheme(
            data: const IconThemeData(color: Colors.white),
            child: NotificationBell(userUid: manager.uid),
          ),
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            width: 1,
            color: Colors.white.withValues(alpha: 0.20),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 206),
            padding: const EdgeInsetsDirectional.only(start: 26),
            child: const _HeaderBrand(),
          ),
        ],
      ),
    );
  }
}

class _DesktopNavButton extends StatelessWidget {
  const _DesktopNavButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 48,
          constraints: const BoxConstraints(minWidth: 86),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF33D6A6).withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? const Color(0xFF33D6A6).withValues(alpha: 0.38)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.78),
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              Positioned(
                bottom: 3,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: selected ? 30 : 0,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF33D6A6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAccount extends StatelessWidget {
  const _HeaderAccount({
    required this.manager,
    required this.onTap,
    this.roleLabel = 'مدير القسم',
    this.compact = false,
  });

  final AppUser manager;
  final VoidCallback onTap;
  final String roleLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: UserAvatar(
          name: manager.name,
          imageUrl: manager.profilePhotoUrl,
          radius: 24,
          borderColor: const Color(0xFFE6AD36),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            UserAvatar(
              name: manager.name,
              imageUrl: manager.profilePhotoUrl,
              radius: 27,
              borderColor: const Color(0xFFE6AD36),
            ),
            const SizedBox(width: 11),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  manager.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  roleLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 7),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _HeaderImage extends StatelessWidget {
  const _HeaderImage({
    required this.assetPath,
    this.width,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  final String assetPath;
  final double? width;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        Uri.base.resolve('assets/$assetPath').toString(),
        width: width,
        fit: fit,
        alignment: alignment,
        filterQuality: FilterQuality.high,
      );
    }
    return Image.asset(
      assetPath,
      width: width,
      fit: fit,
      alignment: alignment,
      filterQuality: FilterQuality.high,
    );
  }
}

class _HeaderBrand extends StatelessWidget {
  const _HeaderBrand({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'NeoTask',
      image: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderImage(
            assetPath: 'assets/images/neotask_brand_mark.png',
            width: compact ? 42 : 52,
          ),
          SizedBox(width: compact ? 8 : 11),
          Text(
            'NeoTask',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: const Color(0xFFF7FAFF),
              fontSize: compact ? 27 : 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.1,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
