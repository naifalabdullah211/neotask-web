import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';

/// Manages the (new — see notification_model.dart doc comment) in-app
/// notification inbox.
///
/// DESIGN NOTE: unlike TaskProvider/GoalProvider (which hold a
/// `notifyListeners()`-driven copy of a GLOBAL cache filtered client-side
/// on every read), notifications are inherently per-recipient, and every
/// screen that needs them (bell-icon badge count, notifications list) is
/// wired directly to `FirestoreService.watchNotificationsForUser(uid)` /
/// `watchUnreadNotificationCountForUser(uid)` via `StreamBuilder` — this
/// mirrors EXACTLY how `manager_home_screen.dart` /
/// `employee_home_screen.dart` already wire the chat-unread-count Badge
/// (`context.watch<MessageProvider>().watchTotalUnreadCountForUser(uid)`).
/// This provider exists mainly so screens can `context.read/watch` it for
/// the mutating actions (mark-read) without importing FirestoreService
/// directly everywhere, keeping the same layering convention as every
/// other provider in this codebase.
class NotificationProvider extends ChangeNotifier {
  Stream<int> watchUnreadCountForUser(String uid) =>
      FirestoreService.watchUnreadNotificationCountForUser(uid);

  Stream<List<AppNotification>> watchForUser(String uid) =>
      FirestoreService.watchNotificationsForUser(uid);

  int unreadCountForUser(String uid) =>
      FirestoreService.getUnreadNotificationCountForUser(uid);

  Future<void> markRead(String notificationId) async {
    await FirestoreService.markNotificationRead(notificationId);
    notifyListeners();
  }

  Future<void> markAllReadForUser(String uid) async {
    final unread = FirestoreService.getNotificationsForUser(
      uid,
    ).where((n) => !n.isRead);
    for (final n in unread) {
      await FirestoreService.markNotificationRead(n.notificationId);
    }
    notifyListeners();
  }
}
