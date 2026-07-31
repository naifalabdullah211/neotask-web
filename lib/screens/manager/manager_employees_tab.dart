import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/invitation_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/task_stats.dart';
import 'employee_stats_detail_screen.dart';

/// Manager's Employees tab:
/// 1) Generate a single-use employee invitation link.
/// 2) Approve/reject pending self-registered employees.
/// 3) View the flat list of all active employees.
class ManagerEmployeesTab extends StatelessWidget {
  const ManagerEmployeesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<AppUser>>(
        stream: FirestoreService.watchEmployees(),
        initialData: FirestoreService.getAllEmployees(),
        builder: (context, snapshot) {
          final employees = snapshot.data ?? [];
          final pending = employees
              .where((u) => u.accountStatus == AccountStatus.pendingApproval)
              .toList();
          final active = employees
              .where((u) => u.accountStatus == AccountStatus.active)
              .toList();
          final rejected = employees
              .where((u) => u.accountStatus == AccountStatus.rejected)
              .toList();
          final deleted = employees
              .where((u) => u.accountStatus == AccountStatus.deleted)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _InviteGeneratorCard(),
              const SizedBox(height: 20),
              if (pending.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active,
                      color: AppColors.statusPending,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'طلبات انضمام بانتظار الموافقة (${pending.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...pending.map((u) => _PendingEmployeeCard(user: u)),
                const SizedBox(height: 20),
              ],
              Text(
                'الموظفون النشطون (${active.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (active.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'لا يوجد موظفون نشطون بعد',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                ...active.map(
                  (u) => _ActiveEmployeeTile(
                    user: u,
                    otherActiveEmployees: active
                        .where((o) => o.uid != u.uid)
                        .toList(),
                  ),
                ),
              if (rejected.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'طلبات مرفوضة (${rejected.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ...rejected.map(
                  (u) => Card(
                    color: Colors.grey.shade100,
                    child: ListTile(
                      leading: const Icon(
                        Icons.block,
                        color: AppColors.statusRejected,
                      ),
                      title: Text(u.name),
                      subtitle: Text('رقم وظيفي: ${u.employeeNumber}'),
                    ),
                  ),
                ),
              ],
              if (deleted.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'حسابات محذوفة (${deleted.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ...deleted.map(
                  (u) => Card(
                    color: Colors.grey.shade100,
                    child: ListTile(
                      leading: const Icon(
                        Icons.person_off,
                        color: AppColors.textSecondary,
                      ),
                      title: Text(
                        u.name,
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      subtitle: Text(u.email),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Active-employee row with a manager-only "delete account" action.
///
/// Deletion is a SOFT delete (accountStatus -> deleted; the Firestore user
/// document itself is preserved for audit/history purposes). Before the
/// deletion is finalized, if the employee has any assigned tasks, the
/// manager must resolve their fate: delete them all, or reassign them all
/// to another active employee.
class _ActiveEmployeeTile extends StatelessWidget {
  final AppUser user;
  final List<AppUser> otherActiveEmployees;
  const _ActiveEmployeeTile({
    required this.user,
    required this.otherActiveEmployees,
  });

  Future<void> _startDeleteFlow(BuildContext context) async {
    final taskProvider = context.read<TaskProvider>();
    final authProvider = context.read<AuthProvider>();
    final managerUid = authProvider.currentUser!.uid;
    final taskCount = taskProvider.taskCountForEmployee(user.uid);

    // Step 1: confirm the deletion itself.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف حساب الموظف'),
        content: Text(
          taskCount > 0
              ? 'سيتم حذف حساب "${user.name}" (حذف ناعم — يمكن مراجعة السجل لاحقًا). '
                    'لدى هذا الموظف $taskCount مهمة مرتبطة، وسيُطلب منك في الخطوة التالية '
                    'تحديد مصيرها.'
              : 'سيتم حذف حساب "${user.name}" (حذف ناعم — يمكن مراجعة السجل لاحقًا). '
                    'لا توجد مهام مرتبطة بهذا الموظف حاليًا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusRejected,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    // Step 2: if there are tasks, resolve their fate before deleting.
    if (taskCount > 0) {
      final resolved = await _resolveTaskFate(
        context,
        taskProvider,
        managerUid,
      );
      if (!resolved) return; // manager backed out of the fate dialog
    }

    // Step 3: perform the soft delete.
    await authProvider.deleteEmployee(user.uid, managerUid);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف حساب "${user.name}" بنجاح')),
      );
    }
  }

  /// Manager-driven password change for ANOTHER user (this employee).
  /// Distinct from `AuthProvider.changeOwnPassword` (self-service, requires
  /// the CURRENT password). Here the manager sets a brand-new password
  /// directly, without knowing/entering the employee's old one — this is
  /// only possible via the `adminResetPassword` Cloud Function (Admin SDK
  /// `admin.auth().updateUser`), which first re-verifies the CALLER is a
  /// manager server-side (never trust the client-side role check alone).
  ///
  /// The password value itself is never logged, displayed again, or stored
  /// anywhere — only a Firestore audit entry (who/whom/when) is written on
  /// success, via `FirestoreService.logPasswordChange`.
  Future<void> _startChangePasswordFlow(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final managerUid = authProvider.currentUser!.uid;
    final managerName = authProvider.currentUser!.name;

    final formKey = GlobalKey<FormState>();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool submitting = false;
    String? errorText;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text('تغيير كلمة المرور — ${user.name}'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'أدخل كلمة مرور جديدة لهذا الموظف. لن تُعرض كلمة المرور '
                    'أو تُخزَّن في أي مكان بعد إنشائها.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newPasswordCtrl,
                    obscureText: obscureNew,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => obscureNew = !obscureNew),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'يرجى إدخال كلمة المرور الجديدة';
                      }
                      if (v.length < 6) {
                        return 'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPasswordCtrl,
                    obscureText: obscureConfirm,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    decoration: InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'يرجى تأكيد كلمة المرور';
                      }
                      if (v != newPasswordCtrl.text) {
                        return 'كلمتا المرور غير متطابقتين';
                      }
                      return null;
                    },
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText!,
                      style: const TextStyle(
                        color: AppColors.statusRejected,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.of(ctx).pop(false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        setState(() {
                          submitting = true;
                          errorText = null;
                        });
                        final error = await authProvider.adminResetPassword(
                          targetUid: user.uid,
                          newPassword: newPasswordCtrl.text,
                        );
                        if (error != null) {
                          setState(() {
                            submitting = false;
                            errorText = error;
                          });
                          return;
                        }
                        await FirestoreService.logPasswordChange(
                          changedByUid: managerUid,
                          changedByName: managerName,
                          changedForUid: user.uid,
                          changedForName: user.name,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop(true);
                      },
                child: submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('تغيير'),
              ),
            ],
          );
        },
      ),
    );

    newPasswordCtrl.dispose();
    confirmPasswordCtrl.dispose();

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تغيير كلمة مرور "${user.name}" بنجاح')),
      );
    }
  }

  /// Presents the delete-vs-reassign choice for the employee's tasks.
  /// Returns true once the manager has made and executed a choice (or if
  /// there are no other employees to reassign to and the manager chooses
  /// delete), false if the manager cancels out entirely.
  Future<bool> _resolveTaskFate(
    BuildContext context,
    TaskProvider taskProvider,
    String managerUid,
  ) async {
    final taskCount = taskProvider.taskCountForEmployee(user.uid);
    AppUser? reassignTarget = otherActiveEmployees.isNotEmpty
        ? otherActiveEmployees.first
        : null;

    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('مصير مهام الموظف'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('لدى "${user.name}" $taskCount مهمة. اختر ما سيحدث لها:'),
              const SizedBox(height: 16),
              if (otherActiveEmployees.isEmpty)
                const Text(
                  'لا يوجد موظفون نشطون آخرون لنقل المهام إليهم، لذا الخيار المتاح هو الحذف فقط.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                )
              else ...[
                const Text(
                  'نقل جميع المهام إلى:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<AppUser>(
                  initialValue: reassignTarget,
                  decoration: const InputDecoration(isDense: true),
                  items: otherActiveEmployees
                      .map(
                        (u) => DropdownMenuItem(value: u, child: Text(u.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => reassignTarget = v),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('إلغاء الحذف بالكامل'),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.statusRejected,
              ),
              onPressed: () => Navigator.of(ctx).pop('delete'),
              child: const Text('حذف كل المهام'),
            ),
            if (otherActiveEmployees.isNotEmpty)
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop('reassign'),
                child: const Text('نقل المهام'),
              ),
          ],
        ),
      ),
    );

    if (choice == null) return false;

    if (choice == 'delete') {
      await taskProvider.deleteAllTasksForEmployee(user.uid);
      return true;
    }

    if (choice == 'reassign' && reassignTarget != null) {
      await taskProvider.reassignAllTasksForEmployee(
        user.uid,
        reassignTarget!.uid,
        managerUid,
      );
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Mini summary card (Level 1): SAME data source as the main dashboard
    // — TaskProvider.tasksForEmployee(uid) filtered/classified via
    // computeTaskStats/computeOnTimeStats (lib/utils/task_stats.dart), the
    // exact functions the dashboard itself calls. No independent counting
    // logic is introduced here, per explicit data-integrity requirement.
    final taskProvider = context.watch<TaskProvider>();
    final employeeTasks = taskProvider.tasksForEmployee(user.uid);
    final stats = computeTaskStats(employeeTasks);
    final onTime = computeOnTimeStats(employeeTasks);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmployeeStatsDetailScreen(employee: user),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.deepBlue.withValues(alpha: 0.1),
                child: Text(
                  user.name.isNotEmpty ? user.name[0] : '?',
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'رقم وظيفي: ${user.employeeNumber}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _MiniStatsRow(stats: stats, onTime: onTime),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.textSecondary,
                ),
                onSelected: (value) {
                  if (value == 'delete') _startDeleteFlow(context);
                  if (value == 'change_password') {
                    _startChangePasswordFlow(context);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'change_password',
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_reset,
                          color: AppColors.steel,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text('تغيير كلمة المرور'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_remove,
                          color: AppColors.statusRejected,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text('حذف الحساب'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Level-1 mini summary row: 6 small colored status icons+counts (same
/// colors/labels as the main dashboard's DashboardMetric map) plus the
/// on-time-completion percentage (tiered color: green ≥80%, orange
/// 50-79%, red <50%). Purely presentational — all numbers are passed in
/// pre-computed from the shared task_stats.dart functions.
class _MiniStatsRow extends StatelessWidget {
  const _MiniStatsRow({required this.stats, required this.onTime});

  final TaskStats stats;
  final OnTimeStats onTime;

  Widget _chip(DashboardMetric metric, int value) {
    final color = dashboardMetricColors[metric]!;
    final icon = dashboardMetricIcons[metric]!;
    return Tooltip(
      message: dashboardMetricLabelsAr[metric]!,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 2),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final percent = onTime.percent;
    final percentColor = percent == null
        ? AppColors.textSecondary
        : onTimePercentTierColor(percent);

    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        _chip(DashboardMetric.total, stats.total),
        _chip(DashboardMetric.pending, stats.pendingDisplay),
        _chip(DashboardMetric.review, stats.submitted),
        _chip(DashboardMetric.completed, stats.completed),
        _chip(DashboardMetric.rejected, stats.rejected),
        _chip(DashboardMetric.overdue, stats.overdue),
        Tooltip(
          message: 'نسبة الإنجاز في الوقت المحدد',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_outlined, size: 13, color: percentColor),
              const SizedBox(width: 2),
              Text(
                percent == null ? '—' : '${percent.round()}%',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: percentColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PendingEmployeeCard extends StatelessWidget {
  final AppUser user;
  const _PendingEmployeeCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.statusPending.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  color: AppColors.statusPending,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'رقم وظيفي: ${user.employeeNumber}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusRejected,
                    ),
                    onPressed: () async {
                      final managerUid = context
                          .read<AuthProvider>()
                          .currentUser!
                          .uid;
                      await context.read<AuthProvider>().rejectEmployee(
                        user.uid,
                        managerUid,
                      );
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('رفض'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusApproved,
                    ),
                    onPressed: () async {
                      final managerUid = context
                          .read<AuthProvider>()
                          .currentUser!
                          .uid;
                      await context.read<AuthProvider>().approveEmployee(
                        user.uid,
                        managerUid,
                      );
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('موافقة'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteGeneratorCard extends StatefulWidget {
  @override
  State<_InviteGeneratorCard> createState() => _InviteGeneratorCardState();
}

class _InviteGeneratorCardState extends State<_InviteGeneratorCard> {
  final _nameCtrl = TextEditingController();
  Invitation? _lastInvite;
  bool _generating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _inviteUrl(String token) {
    final base = Uri.base;
    final origin = '${base.scheme}://${base.authority}${base.path}';
    return '$origin?invite=$token';
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    final managerUid = context.read<AuthProvider>().currentUser!.uid;
    final invite = await context.read<AuthProvider>().generateInvitation(
      managerUid: managerUid,
      expectedName: _nameCtrl.text.trim().isEmpty
          ? null
          : _nameCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _lastInvite = invite;
      _generating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link, color: AppColors.deepBlue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'توليد رابط دعوة موظف جديد',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'رابط استخدام واحد فقط: يصبح غير صالح تلقائيًا بمجرد تسجيل أول موظف من خلاله. لا ينتهي بمرور الوقت.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم الموظف المتوقع (اختياري)',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generating ? null : _generate,
                icon: const Icon(Icons.add_link),
                label: Text(
                  _generating ? 'جارٍ الإنشاء...' : 'إنشاء رابط دعوة',
                ),
              ),
            ),
            if (_lastInvite != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      _inviteUrl(_lastInvite!.token),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.deepBlue,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'تم الإنشاء: ${intl.DateFormat('yyyy/MM/dd HH:mm').format(_lastInvite!.createdAt)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
