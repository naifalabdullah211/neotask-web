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

  static const Color background = Colors.white;
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

  /// Neutral hairline border/divider color used for card outlines, Kanban
  /// column borders, and list separators. Named here as the SINGLE source
  /// of truth for what was previously the hardcoded literal `0xFFE7E9EE`
  /// duplicated independently in `dashboard_stat_widgets.dart` and
  /// `task_kanban_board.dart` — no visual change, just removes the
  /// "magic number" so any future adjustment only happens in one place.
  static const Color divider = Color(0xFFE7E9EE);
}

/// -----------------------------------------------------------------------
/// Design tokens — spacing / radius / icon size / elevation / motion.
///
/// These constants do NOT introduce new visual values on their own; they
/// are named handles for the values the rest of the app already
/// predominantly uses (confirmed by an app-wide audit of
/// `BorderRadius.circular()`, `EdgeInsets.all()`, `fontSize:` and icon
/// `size:` literals). Existing screens/widgets are migrated to reference
/// these tokens incrementally — using a raw number is not "wrong" per se,
/// but every NEW or REFACTORED widget should prefer the token so the app
/// converges on one consistent scale instead of drifting further.
/// -----------------------------------------------------------------------

/// 4pt-based spacing scale. `md`/`lg` are by far the most common paddings
/// found in the audit (16 and 12 respectively across ~54 call sites),
/// confirming a 4/8/12/16/20/24 scale fits the app's existing rhythm
/// rather than imposing an unfamiliar one.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

/// Border-radius scale. Consolidates the 14 distinct radius values found
/// in the audit into 5 named tiers so visually-similar containers (all
/// "cards", all "pills", all "buttons/inputs") stop drifting between
/// 10/12/14/16/18/20 for no semantic reason.
class AppRadius {
  /// Small chips/badges/dots, inner icon containers.
  static const double sm = 8;

  /// Buttons, inputs, segmented controls, list-row inner elements.
  static const double md = 12;

  /// Cards, dialogs — the app's primary "surface" container radius.
  static const double lg = 16;

  /// Chips, drawer, bottom sheets — larger rounded surfaces/pills.
  static const double xl = 20;

  /// Fully round / stadium shape (custom segmented pills, avatars).
  static const double pill = 999;
}

/// Icon-size scale. The audit showed 18/20 dominate everyday inline icons,
/// with 24+ reserved for emphasis (empty-state illustrations, drawer
/// header) — this codifies that de-facto 3-tier pattern.
class AppIconSize {
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 32;
}

/// Elevation scale, mirrored 1:1 with the values already used inside
/// `AppTheme.lightTheme` (card=2, bottom-nav=8) so custom `Container`
/// "card-like" widgets (StatCard, CompletionChartCard, Kanban cards —
/// which currently hand-roll their own `boxShadow` instead of using
/// `Card`) have a named equivalent to align with instead of inventing
/// their own shadow blur/offset per widget.
class AppElevation {
  static const double none = 0;
  static const double low = 2;
  static const double medium = 4;
  static const double high = 8;

  /// Shadow equivalent to [low] elevation — matches `cardTheme`'s
  /// `shadowColor`/blur exactly, for the custom-`Container` "card-like"
  /// widgets that cannot use `Card` directly (e.g. because they need a
  /// gradient background).
  static List<BoxShadow> get lowShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];

  /// Slightly stronger shadow for elements that should read as sitting
  /// "above" ordinary cards (e.g. the chart card, floating pill controls).
  static List<BoxShadow> get mediumShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 14,
      offset: const Offset(0, 5),
    ),
  ];
}

/// Motion tokens. `medium` matches the duration/curve already chosen for
/// the AppDrawer's active-state highlight and the TimeRangeSegmented pill
/// — reused here as the app-wide default so any newly-added
/// state-transition animation (hover, selection, expand/collapse) is
/// consistent with those without every widget re-picking its own numbers.
class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration medium = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 260);
  static const Curve standard = Curves.easeOut;
}

/// Shared type scale.
///
/// The four `*Lg`/`*Md`/`*Sm`-suffixed dark-surface styles below
/// (`headlineLg`, `titleMd`, `bodySm`, `captionSm`) are the ORIGINAL set —
/// deliberately left untouched (same name, same values) since they are
/// already used across auth screens, the drawer header, and empty states
/// and are hardcoded to white/white70/white60 for dark premium
/// backgrounds ([AppColors.primaryGradient] surfaces).
///
/// Everything below that is NEW: a general-purpose scale for ordinary
/// light-surface content (cards, list tiles, dialogs, forms — i.e. most
/// of the app), covering the gap the audit identified — dozens of inline
/// `TextStyle(fontSize: N, ...)` literals scattered 8–30px with no shared
/// scale. Sizes/weights below match the DOMINANT values already found in
/// that audit (10–16 for body/label tiers, 18–26 for titles/numbers), so
/// adopting them is a consolidation, not a redesign.
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

  // --- General-purpose light-surface scale (new) -------------------------

  /// Screen/section titles on light surfaces (e.g. bottom-sheet headers,
  /// dialog titles) — same weight/tracking as [titleMd] but on
  /// [AppColors.textPrimary] explicitly for clarity at call sites that
  /// are never on a dark background.
  static const TextStyle screenTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  /// Card/list-tile primary title text (task titles, contact names, etc).
  static const TextStyle cardTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  /// Standard readable body copy on light surfaces.
  static const TextStyle body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Secondary/supporting text on light surfaces (metadata rows, helper
  /// text, dates) — the light-surface counterpart to [captionSm].
  static const TextStyle bodySecondary = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  /// Small uppercase-ish section labels (e.g. drawer section header,
  /// grouped-list section dividers).
  static const TextStyle sectionLabel = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  /// Large emphasized numbers (stat card values, counters).
  static const TextStyle statValue = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.w800,
  );

  /// Pill/badge/chip label text (status chips, priority badges, counts).
  static const TextStyle badge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
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
        elevation: AppElevation.low,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.deepBlue,
          foregroundColor: Colors.white,
          elevation: AppElevation.none,
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: AppSpacing.xl,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      // Secondary-action button styling — deliberately understated
      // (outlined, no fill) relative to [elevatedButtonTheme]'s solid
      // deepBlue fill, so primary vs. secondary actions are visually
      // distinguishable app-wide without every screen having to choose
      // this on its own (per "primary actions immediately recognizable
      // while secondary actions remain subtle").
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepBlue,
          side: BorderSide(color: AppColors.deepBlue.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: AppSpacing.xl,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.deepBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.deepBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        side: BorderSide(color: AppColors.divider),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.deepBlue,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: AppElevation.high,
      ),
      // Neutral hairline dividers app-wide (list separators, footer rules
      // in the drawer, Kanban-column-header rules) — previously only 1 of
      // 6 `Divider()` call sites specified any color/thickness, so this
      // gives every unstyled `Divider()` a consistent, intentional look
      // instead of falling back to Material's default (which is barely
      // distinguishable from [AppColors.divider] but not guaranteed
      // identical to it).
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      // Default icon color/size for icons that don't explicitly set
      // their own (e.g. plain `Icon(Icons.foo)` with no `color`/`size`
      // args) — keeps them on the app's textSecondary tone and the
      // "medium" tier from [AppIconSize] instead of Material's default
      // black/24.
      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: AppIconSize.md,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        titleTextStyle: AppTextStyles.cardTitle,
        subtitleTextStyle: AppTextStyles.bodySecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
      ),
      // Rounded-top sheet shape for EVERY `showModalBottomSheet` call —
      // closes the gap found in the audit where only 1 of 4 bottom-sheet
      // call sites (`quick_add_task_sheet.dart`) manually wrapped its
      // content in a rounded-top `Container`; the other 3
      // (`chat_thread_screen.dart`, `documents_screen.dart`,
      // `create_poll_screen.dart`) rendered with sharp corners by
      // default. This theme makes the rounded-top look automatic for
      // ALL of them without touching each call site's own content.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        elevation: AppElevation.high,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      // Only 1 SnackBar in the whole app (`app_drawer.dart`'s
      // "قريبًا" stub) explicitly set `behavior: floating`; this makes
      // that the app-wide default so any future/other `SnackBar` matches
      // it without repeating the same style at every call site.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        elevation: AppElevation.high,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      // Rounded outer edge + subtle elevation for the app's premium
      // [AppDrawer] redesign — Flutter's own [DrawerController] already
      // supplies the open/close slide animation with a standard
      // decelerate curve, so no extra motion code is required to satisfy
      // "smooth opening/closing motion with refined easing"; this theme
      // only refines the drawer's static shape/elevation.
      drawerTheme: DrawerThemeData(
        backgroundColor: Colors.white,
        elevation: AppElevation.medium,
        // App is globally forced to RTL (see main.dart), so the `drawer`
        // slot attaches to the screen's RIGHT edge (RTL "start"); round
        // only the LEFT corners (facing the content, away from the
        // screen edge) so the drawer doesn't look clipped on its
        // attached side.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: AppElevation.high,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
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
            borderRadius: BorderRadius.circular(AppRadius.md),
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

/// Same icon used by each `_StatCard` on the manager dashboard
/// (manager_dashboard_tab.dart) — centralized here so the employee mini
/// summary row and the employee stats detail page's stat cards render the
/// IDENTICAL icon+color pairing per metric, with no risk of drifting from
/// the main dashboard's icon choice.
const Map<DashboardMetric, IconData> dashboardMetricIcons = {
  DashboardMetric.total: Icons.assignment_outlined,
  DashboardMetric.completed: Icons.check_circle_outline,
  DashboardMetric.pending: Icons.hourglass_empty,
  DashboardMetric.review: Icons.rate_review_outlined,
  DashboardMetric.rejected: Icons.cancel_outlined,
  DashboardMetric.overdue: Icons.warning_amber_outlined,
};

/// Three-tier color coding for the on-time-completion percentage metric
/// (green ≥80%, orange 50-79%, red <50%) — per explicit spec. Single
/// source of truth shared by the mini summary row and the detail page's
/// prominent on-time card, so both always agree on which color a given
/// percentage renders as.
Color onTimePercentTierColor(double percent) {
  if (percent >= 80) return AppColors.statusApproved; // green
  if (percent >= 50) return const Color(0xFFF59E0B); // orange
  return AppColors.statusRejected; // red
}

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
