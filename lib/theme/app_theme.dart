import 'package:flutter/material.dart';

/// NeoTask color palette — "legendary/premium" scheme: a grounded, deep
/// ink-navy base with a single gold accent, replacing the previous
/// navy→blue→purple gradient (a documented "AI-generated design"
/// anti-pattern: over-saturated multi-hue purple/blue gradients + candy
/// pastel status colors). This palette deliberately uses ONLY two brand
/// hues (ink navy + gold) instead of four competing bright ones, which is
/// what makes premium/luxury interfaces read as intentional rather than
/// templated.
class AppColors {
  // Deep, desaturated "ink" tones — replace the old bright navy/blue.
  static const Color navy = Color(0xFF0F1B2E); // near-black ink navy
  static const Color deepBlue = Color(0xFF1B3A5C); // grounded slate-blue
  static const Color inkDeep = Color(0xFF13293D); // third gradient anchor

  // Single accent hue used for "premium/legendary" highlights — replaces
  // the previous bright violet `purple`.
  static const Color gold = Color(0xFFC9972A);
  static const Color goldLight = Color(0xFFE8C468);

  /// Explicit RCJY brand gold (#E8B84B) — used ONLY for the "favorite"
  /// star icon (filled state) across the app, per explicit hex-value
  /// request. Distinct from `gold`/`goldLight` above (which remain the
  /// general premium accent) so the favorite star has one fixed, exact
  /// brand color regardless of future palette adjustments.
  static const Color favoriteGold = Color(0xFFE8B84B);

  // Replaces the old candy-bright `green` / `lightBlue`.
  static const Color emerald = Color(0xFF15803D);
  static const Color steel = Color(0xFF3E6B8C);

  /// Explicit user-specified brand accent (#33D6A6) for the quick-add task
  /// FAB ONLY. NOTE: this is intentionally a THIRD accent hue outside the
  /// two-hue ink-navy/gold system documented above — added per explicit
  /// request, not blended into the existing status/semantic palette. Do
  /// not reuse this for status colors or other UI without confirming that
  /// is intended, since it reintroduces the multi-hue pattern the rest of
  /// this palette was deliberately designed to avoid.
  static const Color mintAccent = Color(0xFF33D6A6);

  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF11182C);
  static const Color textSecondary = Color(0xFF64748B);

  static const Color statusPending = Color(0xFFB45309); // deep amber
  static const Color statusApproved = Color(0xFF15803D); // = emerald
  static const Color statusRejected = Color(0xFFB3261E); // deep crimson
  static const Color statusInProgress = Color(0xFF3E6B8C); // = steel
  static const Color statusSubmitted = Color(0xFFC9972A); // = gold

  /// Distinct from [statusRejected] on purpose — "متأخرة" (overdue, a
  /// computed due-date metric) and "مرفوضة" (rejected, an actual
  /// TaskStatus) are different concepts and must never share one color,
  /// otherwise dashboard cards/charts showing both side by side become
  /// visually ambiguous. Previously `overdue` inconsistently used
  /// `Colors.orange.shade800` on stat cards but `statusRejected` on the
  /// chart — this constant is now the single source of truth for BOTH.
  static const Color overdue = Color(0xFFD64545);

  /// Monochrome-dark gradient (ink → slate → deep teal-charcoal). No
  /// bright purple/pink anchor — this is the direct fix for the
  /// "purple/pink AI gradient" defect.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, deepBlue, inkDeep],
  );

  /// Reserved for premium highlight touches only (badges, banners) — not
  /// used as a full-screen background gradient.
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, goldLight],
  );
}

/// Shared type scale for "premium" surfaces (auth screens, empty states,
/// marketing-style sections). Keeps heading/body weight & spacing consistent
/// wherever this look is reused, instead of inline TextStyle literals.
class AppTextStyles {
  static const TextStyle headlineLg = TextStyle(
    color: Colors.white,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const TextStyle titleMd = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  static const TextStyle bodySm = TextStyle(
    color: Colors.white70,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle captionSm = TextStyle(
    color: Colors.white60,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.deepBlue,
        primary: AppColors.deepBlue,
        secondary: AppColors.gold,
        tertiary: AppColors.emerald,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.deepBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.deepBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.deepBlue,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // Unifies EVERY SegmentedButton in the app (day/week/month range
      // navigators on the manager dashboard/reports/calendar and employee
      // tasks tab, the priority pickers, the meetings past/upcoming
      // toggle) into one consistent look, replacing Material 3's default
      // fully-pill StadiumBorder + near-invisible outline-color divider —
      // the source of the "غير متماثل" (asymmetric) gap complaint, since
      // that divider color barely contrasts against the white background.
      //
      // `shape` here is the OUTER border of the whole group (all three
      // segments share this ONE RoundedRectangleBorder — Material clips
      // the group to it, individual middle segments get square inner
      // corners automatically), giving a single uniform border-radius
      // instead of a full pill. `side` is used for BOTH that outer border
      // AND every inter-segment divider line (see Flutter's
      // _RenderSegmentedButton.paint, which reuses `enabledBorder.side`
      // for dividers) — a thin, visible ink-navy-tinted line replaces the
      // old barely-visible default.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(
            color: AppColors.deepBlue.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard aggregate-metric colors/labels — SINGLE SOURCE OF TRUTH.
//
// `statusColor()`/`statusLabelAr()` below map a *TaskStatus enum value*
// (assigned/inProgress/submitted/approved/rejected/editRequested) to a
// color — that is a different, narrower vocabulary than what the
// dashboard's stat cards + completion chart show, which are computed
// AGGREGATE buckets ('total', 'pending', 'overdue', etc. — see
// TaskProvider.statsForRange) that don't map 1:1 onto TaskStatus. Any
// dashboard widget rendering one of these aggregate keys (a stat card OR
// a chart bar) MUST read color/label from here, not inline a color
// literal — this is what previously let "متأخرة" drift to two different
// reds between the stat card and the chart.
enum DashboardMetric { total, completed, pending, review, rejected, overdue }

const Map<DashboardMetric, Color> dashboardMetricColors = {
  DashboardMetric.total: AppColors.deepBlue,
  DashboardMetric.completed: AppColors.statusApproved,
  DashboardMetric.pending: AppColors.statusPending,
  DashboardMetric.review: AppColors.statusSubmitted,
  DashboardMetric.rejected: AppColors.statusRejected,
  DashboardMetric.overdue: AppColors.overdue,
};

const Map<DashboardMetric, String> dashboardMetricLabelsAr = {
  DashboardMetric.total: 'الإجمالي',
  DashboardMetric.completed: 'مكتملة',
  DashboardMetric.pending: 'قيد الانتظار',
  DashboardMetric.review: 'بانتظار المراجعة',
  DashboardMetric.rejected: 'مرفوضة',
  DashboardMetric.overdue: 'متأخرة',
};

Color statusColor(String statusName) {
  switch (statusName) {
    case 'assigned':
    case 'notStarted':
      return AppColors.textSecondary;
    case 'inProgress':
      return AppColors.statusInProgress;
    case 'submitted':
      return AppColors.statusSubmitted;
    case 'approved':
    case 'completed':
      return AppColors.statusApproved;
    case 'rejected':
      return AppColors.statusRejected;
    case 'editRequested':
      return AppColors.statusPending;
    default:
      return AppColors.textSecondary;
  }
}

String statusLabelAr(String statusName) {
  switch (statusName) {
    case 'assigned':
      return 'مُسندة';
    case 'notStarted':
      return 'لم يبدأ';
    case 'inProgress':
      return 'قيد التنفيذ';
    case 'submitted':
      return 'بانتظار المراجعة';
    case 'approved':
      return 'مكتملة';
    case 'completed':
      return 'مكتمل';
    case 'rejected':
      return 'مرفوضة';
    case 'editRequested':
      return 'مطلوب تعديل';
    default:
      return statusName;
  }
}
