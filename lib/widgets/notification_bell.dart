import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../screens/shared/notification_center_screen.dart';

/// Bell icon + live unread-count Badge for the app bar — the concrete "🔔
/// bell icon/badge" UI element referenced by the Poll feature's
/// notification requirement (§3). Deliberately styled after the EXACT
/// same Badge()-on-icon pattern already used for chat/review/pending-
/// employee counts (see manager_home_screen.dart /
/// employee_home_screen.dart) even though the underlying persisted
/// notification model itself is new — see notification_model.dart doc
/// comment for the full architectural note on why no prior bell/inbox
/// system existed before this feature.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.userUid});

  final String userUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: context.read<NotificationProvider>().watchUnreadCountForUser(
        userUid,
      ),
      initialData: context.read<NotificationProvider>().unreadCountForUser(
        userUid,
      ),
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        return IconButton(
          tooltip: 'الإشعارات',
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NotificationCenterScreen(userUid: userUid),
              ),
            );
          },
        );
      },
    );
  }
}
