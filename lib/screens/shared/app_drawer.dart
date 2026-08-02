import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/digest_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_avatar.dart';
import '../manager/automation_rules_screen.dart';
import '../manager/bulk_import_screen.dart';
import '../manager/custom_forms_screen.dart';
import '../manager/manager_calendar_screen.dart';
import '../manager/manager_ideas_screen.dart';
import '../manager/manager_my_tasks_screen.dart';
import '../manager/manager_polls_tab.dart';
import '../manager/project_plan_screen.dart';
import 'contacts_screen.dart';
import 'documents_screen.dart';
import 'favorites_screen.dart';
import 'goals_list_screen.dart';
import 'meetings_screen.dart';
import 'neotask_assistant_screen.dart';
import 'settings_screen.dart';
import 'splash_router.dart';

/// Shared NeoTask navigation for managers, employees and read-only designers.
///
/// Navigation targets and role gates stay centralized here. The visual layout
/// is intentionally grouped by user intent so the growing feature set remains
/// scannable without changing any existing permissions or business flows.
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  static final ValueNotifier<String?> _lastOpenedKey = ValueNotifier(null);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser!;
    final isManager = auth.isManager;
    final isDesigner = auth.isDesigner;
    final showManagerTools = isManager || isDesigner;
    final taskProvider = context.watch<TaskProvider>();
    final managerStats = isManager
        ? taskProvider.statsForRange(taskProvider.teamTasks)
        : null;
    final managerDigest = isManager
        ? context.watch<DigestProvider>().todayDigest
        : null;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = screenWidth < 420
        ? screenWidth * .91
        : screenWidth < 900
        ? 356.0
        : 384.0;

    final roleLabel = isManager
        ? 'مدير النظام'
        : isDesigner
        ? 'مصمم · عرض فقط'
        : 'موظف';

    void push(String key, Widget screen) {
      _lastOpenedKey.value = key;
      Navigator.of(context).pop();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }

    Future<void> logout() async {
      Navigator.of(context).pop();
      await context.read<AuthProvider>().logout();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashRouter()),
        (route) => false,
      );
    }

    return Drawer(
      width: drawerWidth,
      elevation: 18,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadiusDirectional.horizontal(
          end: Radius.circular(AppRadius.xl),
        ),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      child: SafeArea(
        child: ValueListenableBuilder<String?>(
          valueListenable: _lastOpenedKey,
          builder: (context, activeKey, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DrawerAccountHeader(
                  name: user.name,
                  roleLabel: roleLabel,
                  employeeNumber: user.employeeNumber,
                  profilePhotoUrl: user.profilePhotoUrl,
                  onClose: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.xl,
                    ),
                    children: [
                      if (isManager && managerStats != null) ...[
                        _DrawerManagerSummary(
                          pending: managerStats.pendingDisplay,
                          submitted: managerStats.submitted,
                          overdue: managerStats.overdue,
                          completedThisWeek:
                              managerDigest?.completedThisWeek,
                          digestText: managerDigest?.messageText,
                          isWeekly: managerDigest?.isWeekly ?? false,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      _DrawerSection(
                        title: 'التخطيط والتنفيذ',
                        icon: Icons.account_tree_outlined,
                        children: [
                          if (showManagerTools)
                            _DrawerNavTile(
                              icon: Icons.view_timeline_outlined,
                              label: 'خطة العمل',
                              isActive: activeKey == 'project_plan',
                              onTap: () => push(
                                'project_plan',
                                ProjectPlanScreen(readOnly: isDesigner),
                              ),
                            ),
                          if (showManagerTools)
                            _DrawerNavTile(
                              icon: Icons.bolt_outlined,
                              label: 'الأتمتة الشرطية',
                              isActive: activeKey == 'automations',
                              onTap: () => push(
                                'automations',
                                AutomationRulesScreen(readOnly: isDesigner),
                              ),
                            ),
                          if (showManagerTools)
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
                            onTap: () => push(
                              'goals',
                              const GoalsListScreen(),
                            ),
                          ),
                          if (showManagerTools)
                            _DrawerNavTile(
                              icon: Icons.checklist_rounded,
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
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (showManagerTools)
                        _DrawerSection(
                          title: 'الإدارة والتواصل',
                          icon: Icons.hub_outlined,
                          children: [
                            _DrawerNavTile(
                              icon: Icons.how_to_vote_outlined,
                              label: 'التصويت',
                              isActive: activeKey == 'polls',
                              onTap: () => push(
                                'polls',
                                ManagerPollsTab(readOnly: isDesigner),
                              ),
                            ),
                            _DrawerNavTile(
                              icon: Icons.lightbulb_outline_rounded,
                              label: 'أفكار المدير',
                              isActive: activeKey == 'manager_ideas',
                              onTap: () => push(
                                'manager_ideas',
                                ManagerIdeasScreen(
                                  manager: user,
                                  readOnly: isDesigner,
                                ),
                              ),
                            ),
                            _DrawerNavTile(
                              icon: Icons.dynamic_form_outlined,
                              label: 'النماذج المخصصة',
                              isActive: activeKey == 'custom_forms',
                              onTap: () => push(
                                'custom_forms',
                                CustomFormsScreen(readOnly: isDesigner),
                              ),
                            ),
                            _DrawerNavTile(
                              icon: Icons.upload_file_outlined,
                              label: 'استيراد Excel / CSV',
                              isActive: activeKey == 'bulk_import',
                              onTap: () => push(
                                'bulk_import',
                                BulkImportScreen(readOnly: isDesigner),
                              ),
                            ),
                          ],
                        ),
                      if (showManagerTools)
                        const SizedBox(height: AppSpacing.lg),
                      _DrawerSection(
                        title: 'المعرفة والموارد',
                        icon: Icons.widgets_outlined,
                        children: [
                          _DrawerNavTile(
                            icon: Icons.auto_stories_outlined,
                            label: 'مركز المعرفة',
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
                          if (showManagerTools || auth.isEmployee)
                            _DrawerNavTile(
                              icon: Icons.star_border_rounded,
                              label: 'المفضلة',
                              isActive: activeKey == 'favorites',
                              onTap: () => push(
                                'favorites',
                                FavoritesScreen(
                                  currentUserUid: isDesigner
                                      ? FirestoreService.getManager()?.uid ??
                                            user.uid
                                      : user.uid,
                                  isManager: showManagerTools,
                                  readOnly: isDesigner,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                _DrawerAccountActions(
                  onSettings: () => push(
                    'settings',
                    const SettingsScreen(),
                  ),
                  onHelp: () => push(
                    'help',
                    const NeoTaskAssistantScreen(),
                  ),
                  onLogout: logout,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DrawerAccountHeader extends StatelessWidget {
  const _DrawerAccountHeader({
    required this.name,
    required this.roleLabel,
    required this.employeeNumber,
    required this.profilePhotoUrl,
    required this.onClose,
  });

  final String name;
  final String roleLabel;
  final String employeeNumber;
  final String? profilePhotoUrl;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadiusDirectional.only(
          bottomEnd: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/neotask_brand_mark.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                semanticLabel: 'NeoTask',
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text(
                  'NeoTask',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.2,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'إغلاق القائمة',
                onPressed: onClose,
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white70,
                  backgroundColor: Colors.white.withValues(alpha: .08),
                  minimumSize: const Size(36, 36),
                  maximumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(
                    name: name,
                    imageUrl: profilePhotoUrl,
                    radius: 27,
                    borderColor: AppColors.goldLight,
                    borderWidth: 1.5,
                  ),
                  PositionedDirectional(
                    end: -1,
                    bottom: 1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.mintAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.navy, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: AppColors.goldLight.withValues(alpha: .35),
                            ),
                          ),
                          child: Text(
                            roleLabel,
                            style: const TextStyle(
                              color: AppColors.goldLight,
                              fontFamily: 'IBMPlexSansArabic',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (employeeNumber.isNotEmpty)
                          Text(
                            '#$employeeNumber',
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .58),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact, live manager overview pinned to the top of the navigation list.
///
/// The three counts deliberately reuse [TaskProvider.statsForRange], the same
/// single source of truth as the dashboard. The optional narrative reuses the
/// persisted daily/weekly digest instead of deriving a competing summary.
class _DrawerManagerSummary extends StatefulWidget {
  const _DrawerManagerSummary({
    required this.pending,
    required this.submitted,
    required this.overdue,
    required this.completedThisWeek,
    required this.digestText,
    required this.isWeekly,
  });

  final int pending;
  final int submitted;
  final int overdue;
  final int? completedThisWeek;
  final String? digestText;
  final bool isWeekly;

  @override
  State<_DrawerManagerSummary> createState() =>
      _DrawerManagerSummaryState();
}

class _DrawerManagerSummaryState extends State<_DrawerManagerSummary> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final digestText = widget.digestText?.trim();
    final detailsText = digestText != null && digestText.isNotEmpty
        ? digestText
        : _fallbackDetails;

    return Semantics(
      container: true,
      label: 'ملخص المدير',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.navy.withValues(alpha: .09),
          ),
          boxShadow: AppElevation.lowShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.navy.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(
                          Icons.summarize_outlined,
                          size: 19,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ملخص المدير',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontFamily: 'IBMPlexSansArabic',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'تحديث مباشر لحالة العمل',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontFamily: 'IBMPlexSansArabic',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? .5 : 0,
                        duration: AppMotion.medium,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 21,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _DrawerSummaryMetric(
                      label: 'قيد الانتظار',
                      value: widget.pending,
                      color: AppColors.deepBlue,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _DrawerSummaryMetric(
                      label: 'بانتظار المراجعة',
                      value: widget.submitted,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _DrawerSummaryMetric(
                      label: 'متأخرة',
                      value: widget.overdue,
                      color: AppColors.statusRejected,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: AppMotion.medium,
              curve: AppMotion.standard,
              child: !_expanded
                  ? const SizedBox.shrink()
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(
                          top: BorderSide(color: AppColors.divider),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: .13),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                child: Text(
                                  widget.isWeekly
                                      ? 'ملخص الأسبوع'
                                      : 'ملخص اليوم',
                                  style: const TextStyle(
                                    color: AppColors.gold,
                                    fontFamily: 'IBMPlexSansArabic',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (widget.completedThisWeek != null) ...[
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    '${widget.completedThisWeek} مكتملة هذا الأسبوع',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontFamily: 'IBMPlexSansArabic',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            detailsText,
                            maxLines: 7,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontFamily: 'IBMPlexSansArabic',
                              fontSize: 11.5,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String get _fallbackDetails {
    if (widget.overdue > 0 || widget.submitted > 0) {
      return 'يحتاج انتباهك ${widget.overdue} مهمة متأخرة و'
          '${widget.submitted} مهمة بانتظار المراجعة.';
    }
    if (widget.pending > 0) {
      return 'لا توجد مهام متأخرة أو مراجعات معلقة. يوجد '
          '${widget.pending} مهمة قيد الانتظار.';
    }
    return 'لا توجد مهام متأخرة أو مراجعات معلقة حاليًا.';
  }
}

class _DrawerSummaryMetric extends StatelessWidget {
  const _DrawerSummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .065),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: .09)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$value',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: color,
              fontSize: 18,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  const _DrawerSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.sm,
            0,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(child: Divider(color: AppColors.divider)),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

class _DrawerNavTile extends StatelessWidget {
  const _DrawerNavTile({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isActive ? Colors.white : AppColors.textPrimary;
    final iconColor = isActive ? AppColors.goldLight : AppColors.deepBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        button: true,
        selected: isActive,
        label: label,
        child: Material(
          color: isActive ? AppColors.navy : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            hoverColor: AppColors.deepBlue.withValues(alpha: .06),
            splashColor: AppColors.gold.withValues(alpha: .15),
            highlightColor: AppColors.deepBlue.withValues(alpha: .04),
            child: AnimatedContainer(
              duration: AppMotion.medium,
              curve: AppMotion.standard,
              height: 47,
              decoration: BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(
                    color: isActive ? AppColors.goldLight : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 9, 0),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: AppMotion.medium,
                    curve: AppMotion.standard,
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white.withValues(alpha: .09)
                          : AppColors.deepBlue.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(icon, size: AppIconSize.md, color: iconColor),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 13.5,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: isActive
                        ? Colors.white.withValues(alpha: .65)
                        : AppColors.textSecondary.withValues(alpha: .55),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerAccountActions extends StatelessWidget {
  const _DrawerAccountActions({
    required this.onSettings,
    required this.onHelp,
    required this.onLogout,
  });

  final VoidCallback onSettings;
  final VoidCallback onHelp;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _DrawerFooterButton(
                    icon: Icons.settings_outlined,
                    label: 'الإعدادات',
                    onTap: onSettings,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _DrawerFooterButton(
                    icon: Icons.help_outline_rounded,
                    label: 'المساعدة',
                    onTap: onHelp,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: TextButton.icon(
                onPressed: onLogout,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.statusRejected,
                  backgroundColor: AppColors.statusRejected.withValues(
                    alpha: .06,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('تسجيل الخروج'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerFooterButton extends StatelessWidget {
  const _DrawerFooterButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepBlue,
          side: const BorderSide(color: AppColors.divider),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        icon: Icon(icon, size: 17),
        label: Text(label, maxLines: 1),
      ),
    );
  }
}
