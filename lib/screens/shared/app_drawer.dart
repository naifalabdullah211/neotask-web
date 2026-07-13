import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'documents_screen.dart';
import 'meetings_screen.dart';
import 'contacts_screen.dart';
import 'favorites_screen.dart';
import 'goals_list_screen.dart';
import '../manager/manager_calendar_screen.dart';

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
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

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

    void push(Widget screen) {
      Navigator.of(context).pop(); // close drawer first
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.navy),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0] : '؟',
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    isManager
                        ? 'مدير'
                        : isDesigner
                        ? 'مصمم (عرض فقط)'
                        : 'موظف',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (showCalendar)
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('التقويم'),
                onTap: () => push(ManagerCalendarScreen(readOnly: isDesigner)),
              ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('الأهداف'),
              onTap: () => push(const GoalsListScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('المستندات'),
              onTap: () => push(
                DocumentsScreen(
                  currentUserUid: user.uid,
                  currentUserName: user.name,
                  isManager: isManager,
                  readOnly: isDesigner,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.groups_2_outlined),
              title: const Text('الاجتماعات'),
              onTap: () => push(
                MeetingsScreen(
                  currentUserUid: user.uid,
                  currentUserName: user.name,
                  isManager: isManager,
                  readOnly: isDesigner,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.contact_phone_outlined),
              title: const Text('جهات الاتصال'),
              onTap: () => push(
                ContactsScreen(
                  currentUserUid: user.uid,
                  isManager: isManager,
                  readOnly: isDesigner,
                ),
              ),
            ),
            // Favorites is intentionally OMITTED for the designer role: it
            // is a per-user starred-tasks list that would always be empty
            // for a designer (favorites are never created by/for a
            // non-participating uid), and its live star/unstar toggle
            // button has no readOnly variant — rather than build one for
            // a screen that would show nothing useful, it is simply not
            // linked from the designer's drawer at all.
            if (!isDesigner)
              ListTile(
                leading: const Icon(Icons.star_border),
                title: const Text('المفضلة'),
                onTap: () => push(
                  FavoritesScreen(
                    currentUserUid: user.uid,
                    isManager: isManager,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
