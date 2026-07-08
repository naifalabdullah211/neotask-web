import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/invitation_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _InviteGeneratorCard(),
              const SizedBox(height: 20),
              if (pending.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.notifications_active,
                        color: AppColors.statusPending, size: 20),
                    const SizedBox(width: 6),
                    Text('طلبات انضمام بانتظار الموافقة (${pending.length})',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ...pending.map((u) => _PendingEmployeeCard(user: u)),
                const SizedBox(height: 20),
              ],
              Text('الموظفون النشطون (${active.length})',
                  style:
                      const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (active.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('لا يوجد موظفون نشطون بعد',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              else
                ...active.map((u) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.deepBlue.withValues(alpha: 0.1),
                          child: Text(
                            u.name.isNotEmpty ? u.name[0] : '?',
                            style: const TextStyle(
                                color: AppColors.deepBlue,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(u.name),
                        subtitle: Text(
                            '${u.email} · رقم وظيفي: ${u.employeeNumber}'),
                        trailing: const Icon(Icons.check_circle,
                            color: AppColors.statusApproved, size: 20),
                      ),
                    )),
              if (rejected.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('طلبات مرفوضة (${rejected.length})',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                ...rejected.map((u) => Card(
                      color: Colors.grey.shade100,
                      child: ListTile(
                        leading: const Icon(Icons.block,
                            color: AppColors.statusRejected),
                        title: Text(u.name),
                        subtitle: Text(u.email),
                      ),
                    )),
              ],
            ],
          );
        },
      ),
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
                const Icon(Icons.person_outline, color: AppColors.statusPending),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${user.email} · رقم وظيفي: ${user.employeeNumber}',
                          style: const TextStyle(fontSize: 12)),
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
                        foregroundColor: AppColors.statusRejected),
                    onPressed: () async {
                      final managerUid =
                          context.read<AuthProvider>().currentUser!.uid;
                      await context
                          .read<AuthProvider>()
                          .rejectEmployee(user.uid, managerUid);
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('رفض'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusApproved),
                    onPressed: () async {
                      final managerUid =
                          context.read<AuthProvider>().currentUser!.uid;
                      await context
                          .read<AuthProvider>()
                          .approveEmployee(user.uid, managerUid);
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
          expectedName:
              _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
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
                  child: Text('توليد رابط دعوة موظف جديد',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
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
                label: Text(_generating ? 'جارٍ الإنشاء...' : 'إنشاء رابط دعوة'),
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
                          fontSize: 12, color: AppColors.deepBlue),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'تم الإنشاء: ${intl.DateFormat('yyyy/MM/dd HH:mm').format(_lastInvite!.createdAt)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
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
