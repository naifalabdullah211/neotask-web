/// "ملخص المدير اليومي/الأسبوعي" (Manager Daily/Weekly Digest) — see
/// `lib/utils/digest_builder.dart` for the full computation architecture
/// note (CLIENT-SIDE LAZY EVALUATION, no Cloud Scheduler — the identical
/// documented trade-off already used by `PollProvider._maybeAutoEndOverduePolls`
/// and `TaskProvider._maybeDispatchReminders`).
///
/// PERSISTENCE: one immutable document per manager per calendar day, keyed
/// by `id = "{managerUid}_{dateKey}"` (dateKey = 'yyyy-MM-dd', device-local
/// date — this project has no server-side clock available without Cloud
/// Functions, so "today" is necessarily whatever the currently-open
/// client's device considers today; this mirrors the same class of
/// trade-off already documented for polls/tasks). Never updated or deleted
/// after creation (see firestore.rules `manager_digests/{digestId}`) —
/// exactly one generation attempt per manager per day, enforced by the
/// lazy "does today's digest already exist?" check in DigestProvider, NOT
/// by a rules-level uniqueness constraint (Firestore has none natively;
/// the deterministic doc ID itself is what prevents duplicates: a second
/// `set()` with the same ID simply overwrites, and the provider never
/// attempts that once a document was already found for today).
///
/// VISIBILITY: manager role ONLY (never surfaced to employees/designer) —
/// enforced at BOTH the UI layer (only reachable from ManagerDashboardTab)
/// and the Firestore rules layer (`isManager() && managerUid == auth.uid`).
library;

class ManagerDigest {
  /// `"{managerUid}_{dateKey}"` — deterministic, used as the Firestore
  /// document ID.
  final String id;
  final String managerUid;

  /// 'yyyy-MM-dd', device-local date this digest was generated for.
  final String dateKey;

  /// 'daily' (Mon-Sat) or 'weekly' (Sun) — see class doc comment on the
  /// UI's "ملخص اليوم" vs "ملخص الأسبوع" label badge.
  final String type;

  final DateTime generatedAt;

  // ---- Raw aggregates (kept alongside `messageText` so the UI/future
  // browsing screen can render structured chips/badges, not just the
  // free-text paragraph, without re-parsing it) ----
  final int overdueCount;
  final List<String> topOverdueTasks;

  /// Each entry: {'title': ..., 'remainingLabel': ...}
  final List<Map<String, String>> urgentPolls;

  final String? bestEmployeeName;
  final double? bestEmployeePercent;
  final String? worstEmployeeName;
  final double? worstEmployeePercent;

  /// Each entry: {'title': String, 'percent': double, 'completed': int, 'total': int}
  final List<Map<String, dynamic>> goalsProgress;

  final int completedThisWeek;
  final int completedThisMonth;
  final bool noRejectionsThisWeek;

  /// Whether the "⚠️ يحتاج انتباهك" section had any content (overdue
  /// tasks or urgent polls) — drives the one-sentence shortcut described
  /// in the requirement ("إذا لا يوجد محتوى تنبيهي: اختصار الرسالة إلى
  /// جملة واحدة").
  final bool hasAlerts;

  /// The final, fully-formatted Arabic multi-paragraph message — the
  /// PRIMARY content rendered by the digest card.
  final String messageText;

  const ManagerDigest({
    required this.id,
    required this.managerUid,
    required this.dateKey,
    required this.type,
    required this.generatedAt,
    required this.overdueCount,
    required this.topOverdueTasks,
    required this.urgentPolls,
    this.bestEmployeeName,
    this.bestEmployeePercent,
    this.worstEmployeeName,
    this.worstEmployeePercent,
    required this.goalsProgress,
    required this.completedThisWeek,
    required this.completedThisMonth,
    required this.noRejectionsThisWeek,
    required this.hasAlerts,
    required this.messageText,
  });

  bool get isWeekly => type == 'weekly';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'managerUid': managerUid,
      'dateKey': dateKey,
      'type': type,
      'generatedAt': generatedAt.toIso8601String(),
      'overdueCount': overdueCount,
      'topOverdueTasks': topOverdueTasks,
      'urgentPolls': urgentPolls,
      'bestEmployeeName': bestEmployeeName,
      'bestEmployeePercent': bestEmployeePercent,
      'worstEmployeeName': worstEmployeeName,
      'worstEmployeePercent': worstEmployeePercent,
      'goalsProgress': goalsProgress,
      'completedThisWeek': completedThisWeek,
      'completedThisMonth': completedThisMonth,
      'noRejectionsThisWeek': noRejectionsThisWeek,
      'hasAlerts': hasAlerts,
      'messageText': messageText,
    };
  }

  factory ManagerDigest.fromMap(Map<dynamic, dynamic> map) {
    return ManagerDigest(
      id: map['id'] as String? ?? '',
      managerUid: map['managerUid'] as String? ?? '',
      dateKey: map['dateKey'] as String? ?? '',
      type: map['type'] as String? ?? 'daily',
      generatedAt: map['generatedAt'] != null
          ? DateTime.parse(map['generatedAt'] as String)
          : DateTime.now(),
      overdueCount: (map['overdueCount'] as num?)?.toInt() ?? 0,
      topOverdueTasks:
          (map['topOverdueTasks'] as List?)?.cast<String>() ?? const [],
      urgentPolls:
          (map['urgentPolls'] as List?)
              ?.map((e) => Map<String, String>.from(e as Map))
              .toList() ??
          const [],
      bestEmployeeName: map['bestEmployeeName'] as String?,
      bestEmployeePercent: (map['bestEmployeePercent'] as num?)?.toDouble(),
      worstEmployeeName: map['worstEmployeeName'] as String?,
      worstEmployeePercent: (map['worstEmployeePercent'] as num?)?.toDouble(),
      goalsProgress:
          (map['goalsProgress'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      completedThisWeek: (map['completedThisWeek'] as num?)?.toInt() ?? 0,
      completedThisMonth: (map['completedThisMonth'] as num?)?.toInt() ?? 0,
      noRejectionsThisWeek: map['noRejectionsThisWeek'] as bool? ?? false,
      hasAlerts: map['hasAlerts'] as bool? ?? false,
      messageText: map['messageText'] as String? ?? '',
    );
  }
}
