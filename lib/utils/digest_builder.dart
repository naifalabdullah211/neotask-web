/// "ملخص المدير اليومي/الأسبوعي" — pure computation + Arabic text
/// generation, no external AI API (per explicit requirement: "منطق شرطي
/// بسيط... بدون استخدام API خارجي لأي ذكاء اصطناعي").
///
/// ARCHITECTURE — CLIENT-SIDE LAZY EVALUATION (explicitly authorized by the
/// user after being informed that a true Cloud Scheduler-backed function
/// requires the Blaze plan with NO workaround — see
/// google.cloud.scheduler_v1 / Cloud Scheduler API's own billing
/// requirement, https://firebase.google.com/pricing, and confirmed by the
/// user's message "بدون حساب كلاود بليز تصرف شوف حل"). This is the exact
/// same documented trade-off already shipped twice in this codebase:
///   - PollProvider._maybeAutoEndOverduePolls (poll_provider.dart)
///   - TaskProvider._maybeDispatchReminders (task_provider.dart)
/// i.e. "the check runs the first time any signed-in client observes the
/// trigger condition", not a genuine background cron. Here the trigger is
/// "has today's ManagerDigest document already been generated?", checked
/// by DigestProvider when the manager's dashboard opens (see
/// DigestProvider.maybeGenerateTodayDigest) — so the digest appears
/// "freshly generated" the first time the manager opens the app on or
/// after a new calendar day, functionally approximating (though not
/// byte-for-byte replicating) a genuine 07:00 scheduled job.
library;

import '../models/criterion_model.dart';
import '../models/goal_model.dart';
import '../models/manager_digest_model.dart';
import '../models/poll_model.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';
import 'task_stats.dart';

/// All inputs the digest needs, already loaded from the live provider
/// caches (see DigestProvider) — this function performs NO Firestore I/O
/// itself, keeping it a pure, independently-testable computation.
class DigestInputs {
  final List<AppTask> allTasks;
  final List<AppPoll> allPolls;
  final List<AppUser> activeEmployees;
  final List<Goal> allGoals;

  /// goalId -> (total, completed) criteria count — see
  /// GoalProvider.progressForGoal.
  final Map<String, ({int total, int completed})> goalProgress;

  final DateTime now;

  const DigestInputs({
    required this.allTasks,
    required this.allPolls,
    required this.activeEmployees,
    required this.allGoals,
    required this.goalProgress,
    required this.now,
  });
}

/// Priority weight — highest first, used to rank overdue tasks by
/// importance ("أكثرها أهمية (أولوية عالية أو الأطول تأخرًا)").
int _priorityWeight(TaskPriority p) {
  switch (p) {
    case TaskPriority.high:
      return 2;
    case TaskPriority.medium:
      return 1;
    case TaskPriority.low:
      return 0;
  }
}

DateTime _startOfWeek(DateTime anchor) {
  final weekday = anchor.weekday; // 1=Mon .. 7=Sun
  final d = DateTime(anchor.year, anchor.month, anchor.day);
  return d.subtract(Duration(days: weekday - 1));
}

/// Builds a full [ManagerDigest] (structured aggregates + final Arabic
/// message) for [managerUid] as of [inputs.now]. [type] is 'daily' or
/// 'weekly' (see DigestProvider — weekly on Sundays).
ManagerDigest buildManagerDigest({
  required String managerUid,
  required String dateKey,
  required String type,
  required DigestInputs inputs,
}) {
  final now = inputs.now;

  // ---------------- (1) Overdue tasks ----------------
  final overdueTasks = inputs.allTasks.where((t) => t.isOverdue).toList()
    ..sort((a, b) {
      final byPriority = _priorityWeight(
        b.priority,
      ).compareTo(_priorityWeight(a.priority));
      if (byPriority != 0) return byPriority;
      // Longer-overdue (earlier dueDate) ranks higher for equal priority.
      return a.dueDate.compareTo(b.dueDate);
    });
  final topOverdueTasks = overdueTasks.take(3).map((t) => t.title).toList();

  // ---------------- (2) Urgent polls (closing within 24h) ----------------
  final urgentPollEntries = <Map<String, String>>[];
  for (final poll in inputs.allPolls) {
    if (poll.status != PollStatus.active) continue;
    final remaining = poll.deadline.difference(now);
    if (remaining.isNegative || remaining > const Duration(hours: 24)) {
      continue;
    }
    urgentPollEntries.add({
      'title': poll.title,
      'remainingLabel': _formatRemaining(remaining),
    });
  }

  // ---------------- (3) Weekly on-time completion per employee ----------------
  // SINGLE SOURCE OF TRUTH reuse (per explicit requirement): the exact same
  // computeOnTimeStats() function already used by
  // employee_stats_detail_screen.dart, applied here to each active
  // employee's CURRENT calendar week (Mon-Sun containing `now`).
  final weekStart = _startOfWeek(now);
  final weekEnd = weekStart.add(
    const Duration(days: 6, hours: 23, minutes: 59),
  );

  String? bestName;
  double? bestPercent;
  String? worstName;
  double? worstPercent;

  for (final employee in inputs.activeEmployees) {
    final weekTasks = inputs.allTasks.where((t) {
      return t.assignedTo == employee.uid &&
          !t.dueDate.isBefore(weekStart) &&
          !t.dueDate.isAfter(weekEnd);
    }).toList();
    final onTime = computeOnTimeStats(weekTasks);
    if (onTime.percent == null) continue; // no completed tasks this week
    final percent = onTime.percent!;
    if (bestPercent == null || percent > bestPercent) {
      bestPercent = percent;
      bestName = employee.name;
    }
    if (worstPercent == null || percent < worstPercent) {
      worstPercent = percent;
      worstName = employee.name;
    }
  }
  // A single qualifying employee is neither "best" nor "worst" in any
  // meaningful comparative sense — suppress the worst side in that case
  // so the message doesn't read as if one person is being singled out
  // for a low score with nothing to compare against.
  if (bestName != null && bestName == worstName) {
    worstName = null;
    worstPercent = null;
  }

  // ---------------- (4) Active goals' progress ----------------
  final activeGoals = inputs.allGoals
      .where((g) => g.endDate.isAfter(now))
      .toList();
  final goalsProgress = <Map<String, dynamic>>[];
  for (final goal in activeGoals) {
    final progress = inputs.goalProgress[goal.goalId];
    if (progress == null || progress.total == 0) continue;
    final percent = (progress.completed / progress.total) * 100;
    goalsProgress.add({
      'title': goal.title,
      'percent': percent,
      'completed': progress.completed,
      'total': progress.total,
    });
  }

  // ---------------- (5) Completed counts + rejections ----------------
  final weekTasksAll = inputs.allTasks
      .where(
        (t) => !t.dueDate.isBefore(weekStart) && !t.dueDate.isAfter(weekEnd),
      )
      .toList();
  final weekStats = computeTaskStats(weekTasksAll);

  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  final monthTasksAll = inputs.allTasks
      .where(
        (t) => !t.dueDate.isBefore(monthStart) && !t.dueDate.isAfter(monthEnd),
      )
      .toList();
  final monthStats = computeTaskStats(monthTasksAll);

  final noRejectionsThisWeek = weekStats.rejected == 0;
  final hasAlerts = overdueTasks.isNotEmpty || urgentPollEntries.isNotEmpty;

  final message = _buildMessage(
    now: now,
    isWeekly: type == 'weekly',
    overdueCount: overdueTasks.length,
    topOverdueTasks: topOverdueTasks,
    urgentPolls: urgentPollEntries,
    bestName: bestName,
    bestPercent: bestPercent,
    worstName: worstName,
    worstPercent: worstPercent,
    goalsProgress: goalsProgress,
    completedThisWeek: weekStats.completed,
    completedThisMonth: monthStats.completed,
    noRejectionsThisWeek: noRejectionsThisWeek,
    hasAlerts: hasAlerts,
  );

  return ManagerDigest(
    id: '${managerUid}_$dateKey',
    managerUid: managerUid,
    dateKey: dateKey,
    type: type,
    generatedAt: now,
    overdueCount: overdueTasks.length,
    topOverdueTasks: topOverdueTasks,
    urgentPolls: urgentPollEntries,
    bestEmployeeName: bestName,
    bestEmployeePercent: bestPercent,
    worstEmployeeName: worstName,
    worstEmployeePercent: worstPercent,
    goalsProgress: goalsProgress,
    completedThisWeek: weekStats.completed,
    completedThisMonth: monthStats.completed,
    noRejectionsThisWeek: noRejectionsThisWeek,
    hasAlerts: hasAlerts,
    messageText: message,
  );
}

String _formatRemaining(Duration d) {
  if (d.inHours >= 1) return '${d.inHours} ساعة';
  if (d.inMinutes >= 1) return '${d.inMinutes} دقيقة';
  return 'أقل من دقيقة';
}

const _arabicWeekdays = {
  1: 'الإثنين',
  2: 'الثلاثاء',
  3: 'الأربعاء',
  4: 'الخميس',
  5: 'الجمعة',
  6: 'السبت',
  7: 'الأحد',
};

String _formatDateAr(DateTime d) {
  final weekday = _arabicWeekdays[d.weekday] ?? '';
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$weekday $dd/$mm/${d.year}';
}

/// Builds the final, fully-formatted Arabic message per the exact
/// requirement structure:
///   1. Greeting + date.
///   2. "⚠️ يحتاج انتباهك" — ONLY if [hasAlerts].
///   3. "📊 أداء الأسبوع" — best/worst performer.
///   4. "🎯 تقدم الأهداف" — active goals' progress.
///   5. "✅ إيجابيات" — completed count, zero rejections, etc.
/// If [hasAlerts] is false, the ENTIRE message shortens to one sentence
/// per the explicit requirement.
String _buildMessage({
  required DateTime now,
  required bool isWeekly,
  required int overdueCount,
  required List<String> topOverdueTasks,
  required List<Map<String, String>> urgentPolls,
  required String? bestName,
  required double? bestPercent,
  required String? worstName,
  required double? worstPercent,
  required List<Map<String, dynamic>> goalsProgress,
  required int completedThisWeek,
  required int completedThisMonth,
  required bool noRejectionsThisWeek,
  required bool hasAlerts,
}) {
  final periodLabel = isWeekly ? 'ملخص الأسبوع' : 'ملخص اليوم';
  final dateLabel = _formatDateAr(now);

  if (!hasAlerts) {
    // One-sentence shortcut per explicit requirement.
    return 'مرحبًا 👋 $periodLabel — $dateLabel\n'
        'كل شي تمام اليوم ✅ $completedThisWeek مهمة مكتملة هذا الأسبوع.';
  }

  final buffer = StringBuffer();
  buffer.writeln('مرحبًا 👋 $periodLabel — $dateLabel');
  buffer.writeln();

  // ---- ⚠️ يحتاج انتباهك ----
  buffer.writeln('⚠️ يحتاج انتباهك');
  if (overdueCount > 0) {
    buffer.writeln('- يوجد $overdueCount مهمة متأخرة عن موعدها.');
    if (topOverdueTasks.isNotEmpty) {
      buffer.writeln('  أهمها: ${topOverdueTasks.join('، ')}');
    }
  }
  for (final poll in urgentPolls) {
    buffer.writeln(
      '- التصويت "${poll['title']}" ينتهي خلال ${poll['remainingLabel']}.',
    );
  }
  buffer.writeln();

  // ---- 📊 أداء الأسبوع ----
  if (bestName != null || worstName != null) {
    buffer.writeln('📊 أداء الأسبوع');
    if (bestName != null && bestPercent != null) {
      buffer.writeln(
        '- الأفضل التزامًا بالمواعيد: $bestName (${bestPercent.toStringAsFixed(0)}٪).',
      );
    }
    if (worstName != null && worstPercent != null) {
      buffer.writeln(
        '- يحتاج تحسين: $worstName (${worstPercent.toStringAsFixed(0)}٪).',
      );
    }
    buffer.writeln();
  }

  // ---- 🎯 تقدم الأهداف ----
  if (goalsProgress.isNotEmpty) {
    buffer.writeln('🎯 تقدم الأهداف');
    for (final g in goalsProgress) {
      final percent = (g['percent'] as double).toStringAsFixed(0);
      buffer.writeln(
        '- ${g['title']}: $percent٪ (${g['completed']} من ${g['total']} معايير مكتملة).',
      );
    }
    buffer.writeln();
  }

  // ---- ✅ إيجابيات ----
  buffer.writeln('✅ إيجابيات');
  buffer.writeln('- $completedThisWeek مهمة مكتملة هذا الأسبوع.');
  buffer.writeln('- $completedThisMonth مهمة مكتملة هذا الشهر.');
  if (noRejectionsThisWeek) {
    buffer.writeln('- لا توجد مهام مرفوضة هذا الأسبوع.');
  }

  return buffer.toString().trimRight();
}

/// Also exports the qualifying-employees loop's criterion-progress helper
/// used by DigestProvider to build `goalProgress` from
/// GoalProvider.progressForGoal — kept as a thin, testable wrapper so
/// DigestProvider does not need to know Criterion internals directly.
({int total, int completed}) computeGoalProgress(List<Criterion> criteria) {
  final completed = criteria
      .where((c) => c.aggregateStatus == CriterionStatus.completed)
      .length;
  return (total: criteria.length, completed: completed);
}
