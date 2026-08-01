import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_avatar.dart';
import 'documents_screen.dart';
import 'meetings_screen.dart';
import 'contacts_screen.dart';
import 'favorites_screen.dart';
import 'goals_list_screen.dart';
import 'settings_screen.dart';
import 'splash_router.dart';
import '../manager/manager_calendar_screen.dart';
import '../manager/manager_polls_tab.dart';
import '../manager/manager_my_tasks_screen.dart';

/// Shared side-menu ("Drawer") giving BOTH manager and employee access to
/// the secondary feature set that does not fit into the bottom
/// [NavigationBar]: المستندات، الاجتماعات، جهات الاتصال، المفضلة — plus a
/// manager-only calendar entry (managers otherwise have no calendar view;
/// employees already have one in their bottom bar, so it is intentionally
/// omitted here for the employee to avoid duplicate entries).
///
/// This mirrors the reference screenshot's sidebar structure. "الرسائل"
/// (Messages) is deliberately NOT duplicated here — it is the existing
/// "المحادثات"/"المحادثة" tab already present in both bottom bars.
///
/// --- Premium redesign notes (this revision) ---
/// Every existing menu item, its role-conditional visibility gate, and its
/// exact `onTap` navigation target are UNCHANGED from the previous
/// revision — only presentation (header, item styling, footer, motion,
/// responsiveness) was reworked. Two gaps were identified while doing so
/// and resolved as documented below rather than pausing to ask, since no
/// existing navigation/business logic needed to change to close either
/// gap:
///
///  1. "Highlight the active page" — the previous drawer had no notion of
///     an active/current page at all, because every item calls
///     `Navigator.push` (a new screen on top of the stack) instead of
///     switching a persistent IndexedStack tab like the bottom
///     [NavigationBar] does. There is therefore no true "currently open
///     page" to detect from the drawer's own build method once it is
///     closed. Rather than force a deeper navigation-observer refactor
///     (explicitly out of scope — the brief says not to change navigation
///     structure), the drawer now tracks the *most recently opened* item
///     for the lifetime of the current session via a small static
///     [ValueNotifier] (`_lastOpenedKey`) and highlights that entry the
///     next time the drawer is opened. This gives a real, persistent
///     "active" affordance without altering how routing works.
///  2. Footer "Settings" and "Help" — neither screen exists anywhere in
///     the codebase. Building full new feature screens is out of scope
///     for a visual-refinement-only pass, so both are wired to a
///     lightweight "قريبًا" (coming soon) snackbar for now. Logout is
///     newly added here (reusing the exact existing
///     `AuthProvider.logout()` + `SplashRouter` pattern already used in
///     all three AppBar logout buttons) — the AppBar logout buttons are
///     left in place untouched, so no existing affordance is removed.
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  /// Session-lifetime "which drawer item was opened last" tracker — see
  /// gap (1) in the class doc comment above. Static so it survives this
  /// widget being torn down/rebuilt every time the drawer opens/closes
  /// (Scaffold instantiates `const AppDrawer()` fresh each time), but it
  /// naturally resets on full app restart/logout since it is in-memory
  /// only, which is the correct behaviour for a "current page" indicator.
  static final ValueNotifier<String?> _lastOpenedKey = ValueNotifier(null);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser!;
    final isManager = auth.isManager;
    final isDesigner = auth.isDesigner;
    // Per the designer role's "1-a" answer (read EVERYTHING) the designer
    // must also see the manager-only Calendar entry, but must never get
    // any of the write affordances (upload/create/add FABs) in
    // Documents/Meetings/Contacts — see the `readOnly` params below.
    final showCalendar = isManager || isDesigner;

    final roleLabel = isManager
        ? 'مدير'
        : isDesigner
        ? 'مصمم (عرض فقط)'
        : 'موظف';

    void push(String key, Widget screen) {
      _lastOpenedKey.value = key;
      Navigator.of(context).pop(); // close drawer first
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }

    void showComingSoon(String feature) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$feature — قريبًا'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    Future<void> logout() async {
      Navigator.of(context).pop();
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SplashRouter()),
          (route) => false,
        );
      }
    }

    // Responsive width: standard Material drawer proportions on phones,
    // but capped on tablet/desktop so it never grows into an
    // uncomfortably wide panel — spec requirement: "full responsiveness
    // across phones, tablets and desktop layouts".
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth < 420
        ? screenWidth * 0.86
        : screenWidth < 900
        ? 340.0
        : 380.0;

    return Drawer(
      width: drawerWidth,
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: ValueListenableBuilder<String?>(
          valueListenable: _lastOpenedKey,
          builder: (context, activeKey, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DrawerHeader(
                  name: user.name,
                  roleLabel: roleLabel,
                  employeeNumber: user.employeeNumber,
                  profilePhotoUrl: user.profilePhotoUrl,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      const _SectionLabel('التنقل الرئيسي'),
                      if (showCalendar)
                        _DrawerNavTile(
                          icon: Icons.calendar_month_outlined,
                          label: 'التقويم',
                          isActive: activeKey == 'calendar',
                          onTap: () => push(
                            'calendar',
                            ManagerCalendarScreen(readOnly: isDesigner),
                          ),
                        ),
                      _DrawerNavTile(
                        icon: Icons.flag_outlined,
                        label: 'الأهداف',
                        isActive: activeKey == 'goals',
                        onTap: () => push('goals', const GoalsListScreen()),
                      ),
                      if (isManager || isDesigner)
                        _DrawerNavTile(
                          icon: Icons.how_to_vote_outlined,
                          label: 'تصويت',
                          isActive: activeKey == 'polls',
                          onTap: () => push(
                            'polls',
                            ManagerPollsTab(readOnly: isDesigner),
                          ),
                        ),
                      if (isManager || isDesigner)
                        _DrawerNavTile(
                          icon: Icons.checklist,
                          label: 'مهامي الشخصية',
                          isActive: activeKey == 'my_tasks',
                          onTap: () => push(
                            'my_tasks',
                            ManagerMyTasksScreen(
                              readOnly: isDesigner,
                              managerUid: isDesigner
                                  ? FirestoreService.getManager()?.uid
                                  : user.uid,
                            ),
                          ),
                        ),
                      _DrawerNavTile(
                        icon: Icons.folder_outlined,
                        label: 'المستندات',
                        isActive: activeKey == 'documents',
                        onTap: () => push(
                          'documents',
                          DocumentsScreen(
                            currentUserUid: user.uid,
                            currentUserName: user.name,
                            isManager: isManager,
                            readOnly: isDesigner,
                          ),
                        ),
                      ),
                      _DrawerNavTile(
                        icon: Icons.groups_2_outlined,
                        label: 'الاجتماعات',
                        isActive: activeKey == 'meetings',
                        onTap: () => push(
                          'meetings',
                          MeetingsScreen(
                            currentUserUid: user.uid,
                            currentUserName: user.name,
                            isManager: isManager,
                            readOnly: isDesigner,
                          ),
                        ),
                      ),
                      _DrawerNavTile(
                        icon: Icons.contact_phone_outlined,
                        label: 'جهات الاتصال',
                        isActive: activeKey == 'contacts',
                        onTap: () => push(
                          'contacts',
                          ContactsScreen(
                            currentUserUid: user.uid,
                            isManager: isManager,
                            readOnly: isDesigner,
                          ),
                        ),
                      ),
                      if (isManager || isDesigner || auth.isEmployee)
                        _DrawerNavTile(
                          icon: Icons.star_border,
                          label: 'المفضلة',
                          isActive: activeKey == 'favorites',
                          onTap: () => push(
                            'favorites',
                            FavoritesScreen(
                              currentUserUid: isDesigner
                                  ? FirestoreService.getManager()?.uid ??
                                        user.uid
                                  : user.uid,
                              isManager: isManager || isDesigner,
                              readOnly: isDesigner,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const _DrawerFooter(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Column(
                    children: [
                      _DrawerNavTile(
                        icon: Icons.settings_outlined,
                        label: 'الإعدادات',
                        isActive: activeKey == 'settings',
                        muted: true,
                        onTap: () => push('settings', const SettingsScreen()),
                      ),
                      _DrawerNavTile(
                        icon: Icons.help_outline,
                        label: 'المساعدة',
                        isActive: false,
                        muted: true,
                        onTap: () => showComingSoon('المساعدة'),
                      ),
                      _DrawerNavTile(
                        icon: Icons.logout,
                        label: 'تسجيل الخروج',
                        isActive: false,
                        muted: true,
                        iconColor: AppColors.statusRejected,
                        onTap: logout,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Premium profile header: larger avatar with a gold ring, name, a role
/// "badge" chip, and a muted secondary line (الرقم الوظيفي) — all rendered
/// over the app's EXISTING [AppColors.primaryGradient] (ink navy → slate →
/// charcoal-teal), per the explicit instruction to reuse existing primary
/// colors rather than introduce a new brand hue.
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.name,
    required this.roleLabel,
    required this.employeeNumber,
    required this.profilePhotoUrl,
  });

  final String name;
  final String roleLabel;
  final String employeeNumber;
  final String? profilePhotoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            name: name,
            imageUrl: profilePhotoUrl,
            radius: 35,
            borderColor: AppColors.gold,
            borderWidth: 2,
          ),
          const SizedBox(height: 14),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
            ),
            child: Text(
              roleLabel,
              style: const TextStyle(
                color: AppColors.goldLight,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          if (employeeNumber.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'رقم وظيفي: $employeeNumber',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small uppercase-style section label distinguishing the primary
/// navigation list from any secondary/supporting text — spec requirement:
/// "clear distinction between primary navigation labels and secondary
/// information".
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// A thin divider + section rendered between the scrollable nav list and
/// the footer actions — spec requirement: "separated visually from the
/// main navigation with elegant spacing and a thin divider".
class _DrawerFooter extends StatelessWidget {
  const _DrawerFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        height: 1,
        color: AppColors.textSecondary.withValues(alpha: 0.15),
      ),
    );
  }
}

/// Polished, reusable nav-item component: fixed comfortable height,
/// rounded corners, aligned leading icon in its own soft tinted chip, a
/// filled soft-accent container when [isActive], and subtle
/// hover/pressed feedback via [InkWell] (hover only has a visible effect
/// on web/desktop pointer input, per spec: "subtle hover, pressed ...
/// animations").
class _DrawerNavTile extends StatelessWidget {
  const _DrawerNavTile({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.muted = false,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool muted;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final Color fg = iconColor ?? (isActive ? AppColors.gold : AppColors.navy);
    final Color labelColor = muted
        ? AppColors.textSecondary
        : (isActive ? AppColors.navy : AppColors.textPrimary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: isActive
            ? AppColors.gold.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          hoverColor: AppColors.navy.withValues(alpha: 0.05),
          splashColor: AppColors.gold.withValues(alpha: 0.18),
          highlightColor: AppColors.gold.withValues(alpha: 0.10),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.gold.withValues(alpha: 0.18)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: fg),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
