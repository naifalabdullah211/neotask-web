import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_avatar.dart';

/// Read-only employees tab for the `designer` observer role. Mirrors
/// ManagerEmployeesTab's list-display sections (pending / active / rejected
/// / deleted) per the "1-a" full-read-access answer, but with the
/// invite-generator card and ALL approve/reject/delete actions stripped
/// entirely — every row here is a plain, non-interactive Card/ListTile.
class DesignerEmployeesTab extends StatelessWidget {
  const DesignerEmployeesTab({super.key});

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
                ...pending.map(
                  (u) =>
                      _EmployeeTile(user: u, statusLabel: 'بانتظار الموافقة'),
                ),
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
                ...active.map((u) => _EmployeeTile(user: u)),
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

class _EmployeeTile extends StatelessWidget {
  final AppUser user;
  final String? statusLabel;
  const _EmployeeTile({required this.user, this.statusLabel});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: UserAvatar(
          name: user.name,
          imageUrl: user.profilePhotoUrl,
          radius: 20,
          borderColor: AppColors.deepBlue.withValues(alpha: 0.22),
          borderWidth: 1,
          backgroundColor: AppColors.deepBlue.withValues(alpha: 0.1),
        ),
        title: Text(user.name),
        subtitle: Text('رقم وظيفي: ${user.employeeNumber}'),
        trailing: statusLabel != null
            ? Chip(
                label: Text(statusLabel!, style: const TextStyle(fontSize: 11)),
                backgroundColor: AppColors.statusPending.withValues(
                  alpha: 0.15,
                ),
              )
            : null,
      ),
    );
  }
}
