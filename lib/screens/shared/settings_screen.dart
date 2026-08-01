import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_avatar.dart';

/// "الإعدادات" (Settings) — previously a completely empty placeholder
/// wired to a "قريبًا" (coming soon) snackbar (see app_drawer.dart doc
/// comment, gap #2). This is the first real implementation, containing
/// three sections per the explicit 3-part feature request:
///
///   (أ) "الإشعارات الصوتية" — two independent sound on/off toggles
///       (messages, tasks), persisted per-user on `users/{uid}` via
///       `soundMessagesEnabled`/`soundTasksEnabled` (see AppUser model).
///       NOTE (flagged, not glossed over): this screen wires the toggle
///       STATE + PERSISTENCE only. No audio-playback feature existed
///       anywhere in this codebase before this change (confirmed via
///       exhaustive search — no audio package, no sound assets, no
///       playback code in message_provider.dart/task_provider.dart), so
///       these toggles do not yet gate any actual sound. Wiring real
///       playback is a separate, explicitly deferred follow-up once an
///       audio package + sound assets are chosen.
///   (ب) "التذكيرات" — one on/off toggle for the EXISTING automatic
///       due-soon/overdue task reminder feature (see
///       TaskProvider._maybeDispatchReminders, which now checks this
///       user's `remindersEnabled` flag before dispatching to them).
///   (ج) "الحساب" — personal password self-change (current password +
///       new password + confirmation), using
///       AuthProvider.changeOwnPassword (reauthenticateWithCredential +
///       updatePassword). Explicitly DISTINCT from the manager-driven
///       "تغيير كلمة المرور" action in the Employees screen (Part 1),
///       which changes ANOTHER user's password via a Cloud Function.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _savingSoundMessages = false;
  bool _savingSoundTasks = false;
  bool _savingReminders = false;
  bool _uploadingProfilePhoto = false;

  Future<void> _pickAndUploadProfilePhoto(AuthProvider auth) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حجم الصورة يجب ألا يتجاوز 5 ميجابايت')),
        );
      }
      return;
    }

    setState(() => _uploadingProfilePhoto = true);
    try {
      final url = await CloudinaryService.uploadBytes(
        bytes: bytes,
        filename: 'profile_${auth.currentUser!.uid}_${picked.name}',
      );
      await auth.updateOwnProfilePhoto(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الصورة الشخصية'),
            backgroundColor: AppColors.statusApproved,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذّر رفع الصورة: $error'),
            backgroundColor: AppColors.statusRejected,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingProfilePhoto = false);
    }
  }

  Future<void> _updatePreference({
    required AppUser user,
    required AuthProvider auth,
    required String field,
    required bool value,
    required void Function(bool saving) setSaving,
  }) async {
    setSaving(true);
    try {
      final updated = switch (field) {
        'soundMessagesEnabled' => user.copyWith(soundMessagesEnabled: value),
        'soundTasksEnabled' => user.copyWith(soundTasksEnabled: value),
        'remindersEnabled' => user.copyWith(remindersEnabled: value),
        _ => user,
      };
      await FirestoreService.saveUser(updated);
      auth.refreshCurrentUser();
    } finally {
      if (mounted) setSaving(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _SectionHeader(icon: Icons.account_circle_outlined, title: 'الملف الشخصي'),
            const SizedBox(height: AppSpacing.sm),
            _SettingsCard(
              children: [
                Row(
                  children: [
                    UserAvatar(
                      name: user.name,
                      imageUrl: user.profilePhotoUrl,
                      radius: 38,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'الرقم الوظيفي: ${user.employeeNumber}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          OutlinedButton.icon(
                            onPressed: _uploadingProfilePhoto
                                ? null
                                : () => _pickAndUploadProfilePhoto(auth),
                            icon: _uploadingProfilePhoto
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.add_a_photo_outlined, size: 18),
                            label: Text(
                              _uploadingProfilePhoto
                                  ? 'جارٍ رفع الصورة...'
                                  : user.profilePhotoUrl == null
                                  ? 'إضافة صورة شخصية'
                                  : 'تغيير الصورة الشخصية',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            _SectionHeader(
              icon: Icons.volume_up_outlined,
              title: 'الإشعارات الصوتية',
            ),
            const SizedBox(height: AppSpacing.sm),
            _SettingsCard(
              children: [
                _ToggleRow(
                  label: 'صوت الرسائل',
                  subtitle: 'تشغيل صوت عند استلام رسالة جديدة',
                  value: user.soundMessagesEnabled,
                  loading: _savingSoundMessages,
                  onChanged: (v) => _updatePreference(
                    user: user,
                    auth: auth,
                    field: 'soundMessagesEnabled',
                    value: v,
                    setSaving: (s) => setState(() => _savingSoundMessages = s),
                  ),
                ),
                const Divider(height: 1),
                _ToggleRow(
                  label: 'صوت المهام',
                  subtitle: 'تشغيل صوت عند إسناد أو تحديث مهمة',
                  value: user.soundTasksEnabled,
                  loading: _savingSoundTasks,
                  onChanged: (v) => _updatePreference(
                    user: user,
                    auth: auth,
                    field: 'soundTasksEnabled',
                    value: v,
                    setSaving: (s) => setState(() => _savingSoundTasks = s),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            _SectionHeader(
              icon: Icons.notifications_active_outlined,
              title: 'التذكيرات',
            ),
            const SizedBox(height: AppSpacing.sm),
            _SettingsCard(
              children: [
                _ToggleRow(
                  label: 'تذكيرات المهام',
                  subtitle: 'تلقّي تذكير عند اقتراب الاستحقاق أو تأخر المهمة',
                  value: user.remindersEnabled,
                  loading: _savingReminders,
                  onChanged: (v) => _updatePreference(
                    user: user,
                    auth: auth,
                    field: 'remindersEnabled',
                    value: v,
                    setSaving: (s) => setState(() => _savingReminders = s),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            _SectionHeader(icon: Icons.lock_outline, title: 'الحساب'),
            const SizedBox(height: AppSpacing.sm),
            const _SettingsCard(children: [_ChangeOwnPasswordForm()]),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.deepBlue),
        const SizedBox(width: AppSpacing.sm),
        Text(title, style: AppTextStyles.screenTitle),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(children: children),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.loading = false,
  });

  final String label;
  final String subtitle;
  final bool value;
  final bool loading;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (loading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: value,
              activeThumbColor: AppColors.gold,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

/// Part 3(ج) — self-service password change. Explicitly DIFFERENT from
/// the manager-driven Part 1 flow: here the CURRENTLY signed-in user
/// (any role) changes THEIR OWN password by first proving they know the
/// current one (Firebase Auth `reauthenticateWithCredential`), then
/// `updatePassword`. No Firestore write happens here at all.
class _ChangeOwnPasswordForm extends StatefulWidget {
  const _ChangeOwnPasswordForm();

  @override
  State<_ChangeOwnPasswordForm> createState() => _ChangeOwnPasswordFormState();
}

class _ChangeOwnPasswordFormState extends State<_ChangeOwnPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();
    final error = await auth.changeOwnPassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (error == null) {
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      _formKey.currentState?.reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تغيير كلمة المرور بنجاح'),
          backgroundColor: AppColors.statusApproved,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.statusRejected,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'تغيير كلمة مرور حسابك الحالي',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _currentCtrl,
            obscureText: _obscureCurrent,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            decoration: InputDecoration(
              labelText: 'كلمة المرور الحالية',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'أدخل كلمة المرور الحالية' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _newCtrl,
            obscureText: _obscureNew,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            decoration: InputDecoration(
              labelText: 'كلمة المرور الجديدة',
              prefixIcon: const Icon(Icons.lock_reset_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNew ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'أدخل كلمة المرور الجديدة';
              if (v.length < 6) {
                return 'يجب أن تكون 6 أحرف على الأقل';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: _obscureNew,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            decoration: const InputDecoration(
              labelText: 'تأكيد كلمة المرور الجديدة',
              prefixIcon: Icon(Icons.check_circle_outline),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'أعد كتابة كلمة المرور الجديدة';
              }
              if (v != _newCtrl.text) return 'كلمتا المرور غير متطابقتين';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('تغيير كلمة المرور'),
          ),
        ],
      ),
    );
  }
}
