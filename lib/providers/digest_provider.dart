import 'package:flutter/foundation.dart';
import '../models/manager_digest_model.dart';
import '../models/task_model.dart';
import '../models/poll_model.dart';
import '../models/user_model.dart';
import '../models/goal_model.dart';
import '../services/firestore_service.dart';
import '../utils/digest_builder.dart';

/// Manages the "ملخص المدير اليومي/الأسبوعي" (Manager Daily/Weekly Digest)
/// lifecycle. See `lib/utils/digest_builder.dart`'s class doc comment for
/// the full CLIENT-SIDE LAZY EVALUATION architecture rationale (no Cloud
/// Scheduler — Blaze-plan requirement is absolute and was explicitly
/// declined by the manager three times in this project's history).
///
/// USAGE: call [maybeGenerateTodayDigest] once when ManagerDashboardTab
/// opens (mirrors PollProvider/TaskProvider's existing "check on every
/// live snapshot" pattern, but here triggered on screen-open rather than
/// on every task/poll mutation, since the digest is a once-per-day
/// artifact, not a per-mutation reconciliation). If today's digest already
/// exists, this is a no-op single read (cheap); otherwise it computes and
/// persists a new one exactly once.
class DigestProvider extends ChangeNotifier {
  ManagerDigest? _todayDigest;
  ManagerDigest? get todayDigest => _todayDigest;

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  String? _lastCheckedDateKey;

  static String dateKeyFor(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  /// Sunday = weekly digest; every other day = daily digest, per the
  /// explicit requirement ("ملخص الأسبوع، كل يوم أحد").
  static String typeFor(DateTime d) =>
      d.weekday == DateTime.sunday ? 'weekly' : 'daily';

  /// The lazy check-on-open entry point. Safe to call redundantly (e.g. on
  /// every ManagerDashboardTab rebuild) — internally guarded so the
  /// Firestore existence check + computation only actually runs once per
  /// calendar day per provider instance, and errors are caught so a
  /// transient Firestore failure never crashes the dashboard.
  Future<void> maybeGenerateTodayDigest({
    required String managerUid,
    required List<AppTask> allTasks,
    required List<AppPoll> allPolls,
    required List<AppUser> activeEmployees,
    required List<Goal> allGoals,
    required Map<String, ({int total, int completed})> goalProgress,
  }) async {
    final now = DateTime.now();
    final dateKey = dateKeyFor(now);

    if (_lastCheckedDateKey == dateKey && _todayDigest != null) {
      return; // already generated/fetched this session for today
    }

    try {
      final existing = await FirestoreService.getDigest(managerUid, dateKey);
      if (existing != null) {
        _todayDigest = existing;
        _lastCheckedDateKey = dateKey;
        notifyListeners();
        return;
      }

      _isGenerating = true;
      notifyListeners();

      final digest = buildManagerDigest(
        managerUid: managerUid,
        dateKey: dateKey,
        type: typeFor(now),
        inputs: DigestInputs(
          allTasks: allTasks,
          allPolls: allPolls,
          activeEmployees: activeEmployees,
          allGoals: allGoals,
          goalProgress: goalProgress,
          now: now,
        ),
      );

      await FirestoreService.saveDigest(digest);
      _todayDigest = digest;
      _lastCheckedDateKey = dateKey;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DigestProvider: generation failed: $e');
      }
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  Future<List<ManagerDigest>> getHistory(String managerUid) =>
      FirestoreService.getDigestHistory(managerUid);
}
