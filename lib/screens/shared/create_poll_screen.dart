import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/poll_provider.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_theme.dart';

/// Manager-only screen for creating a new "تصويت" (Poll) — per explicit
/// requirement #1: title (required), long description (optional), an
/// optional image/PDF attachment via the SAME Cloudinary upload mechanism
/// used elsewhere in the app (see CloudinaryService / chat_thread_screen.
/// dart / documents_screen.dart), multi-select of ACTIVE employees, and a
/// MANDATORY closing date+time — the form's own [_save] validation and the
/// initial non-nullable [_deadline] field together make "create without a
/// deadline" impossible from this screen; [PollProvider.createPoll] takes
/// a required (non-nullable) `deadline` parameter as a second layer of
/// enforcement at the API level.
class CreatePollScreen extends StatefulWidget {
  const CreatePollScreen({super.key});

  @override
  State<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  final Set<String> _selectedEmployeeUids = {};

  // No default deadline is pre-filled deliberately — an empty/null
  // deadline forces the manager to make an explicit choice, reinforcing
  // the "no poll without a deadline" requirement visually (see _deadline
  // == null branch in build()), rather than silently defaulting to "now +
  // 1 day" the way ManagerCreateTaskScreen's dueDate does for tasks.
  DateTime? _deadline;

  String? _attachmentUrl;
  String? _attachmentName;
  String? _attachmentType; // 'image' | 'file'
  bool _uploadingAttachment = false;

  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _deadline != null
          ? TimeOfDay.fromDateTime(_deadline!)
          : const TimeOfDay(hour: 17, minute: 0),
    );
    if (pickedTime == null) return;
    setState(() {
      _deadline = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _pickAttachment() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_outlined,
                color: AppColors.deepBlue,
              ),
              title: const Text('صورة'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppColors.deepBlue,
              ),
              title: const Text('ملف PDF'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    List<int>? bytes;
    String? filename;

    if (choice == 'image') {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;
      bytes = await picked.readAsBytes();
      filename = picked.name;
    } else {
      final result = await FilePicker.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.isEmpty) return;
      bytes = result.files.first.bytes;
      filename = result.files.first.name;
    }

    if (bytes == null) return;
    if (!mounted) return;

    setState(() => _uploadingAttachment = true);
    try {
      final url = await CloudinaryService.uploadBytes(
        bytes: bytes,
        filename: filename,
      );
      if (!mounted) return;
      setState(() {
        _attachmentUrl = url;
        _attachmentName = filename;
        _attachmentType = choice;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذّر رفع المرفق: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingAttachment = false);
    }
  }

  void _removeAttachment() {
    setState(() {
      _attachmentUrl = null;
      _attachmentName = null;
      _attachmentType = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تحديد موعد إغلاق التصويت — لا يمكن الحفظ بدونه'),
        ),
      );
      return;
    }
    if (_deadline!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('موعد الإغلاق يجب أن يكون في المستقبل')),
      );
      return;
    }
    if (_selectedEmployeeUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار موظف واحد على الأقل للمشاركة بالتصويت'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final managerUid = context.read<AuthProvider>().currentUser!.uid;
    try {
      await context.read<PollProvider>().createPoll(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        participantUids: _selectedEmployeeUids.toList(),
        deadline: _deadline!,
        createdBy: managerUid,
        attachmentUrl: _attachmentUrl,
        attachmentName: _attachmentName,
        attachmentType: _attachmentType,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إنشاء التصويت بنجاح')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ التصويت، حاول مجددًا: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employees = context.read<PollProvider>().getActiveEmployees();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('تصويت جديد')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'عنوان / الفكرة المطروحة للتصويت',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'أدخل عنوان التصويت'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'وصف تفصيلي (اختياري)',
                ),
              ),
              const SizedBox(height: 14),

              // ---- optional attachment ----
              const Text(
                'مرفق (اختياري)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              if (_attachmentUrl != null)
                Card(
                  child: ListTile(
                    leading: Icon(
                      _attachmentType == 'image'
                          ? Icons.image_outlined
                          : Icons.picture_as_pdf_outlined,
                      color: AppColors.deepBlue,
                    ),
                    title: Text(_attachmentName ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _removeAttachment,
                    ),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _uploadingAttachment ? null : _pickAttachment,
                  icon: _uploadingAttachment
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file),
                  label: Text(
                    _uploadingAttachment ? 'جارٍ الرفع...' : 'إضافة مرفق',
                  ),
                ),
              const SizedBox(height: 20),

              // ---- mandatory deadline ----
              const Text(
                'موعد إغلاق التصويت (مطلوب)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'لا يمكن إنشاء التصويت بدون تحديد موعد إغلاق',
                style: TextStyle(fontSize: 12, color: AppColors.statusRejected),
              ),
              const SizedBox(height: 8),
              Card(
                color: _deadline == null
                    ? AppColors.statusRejected.withValues(alpha: 0.06)
                    : null,
                child: ListTile(
                  leading: Icon(
                    Icons.event_busy_outlined,
                    color: _deadline == null
                        ? AppColors.statusRejected
                        : AppColors.deepBlue,
                  ),
                  title: Text(
                    _deadline == null
                        ? 'لم يتم تحديد موعد الإغلاق'
                        : intl.DateFormat(
                            'yyyy/MM/dd — HH:mm',
                          ).format(_deadline!),
                  ),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: _pickDeadline,
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'الموظفون المشاركون في التصويت',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'يمكن اختيار أكثر من موظف واحد (الموظفون النشطون فقط)',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              if (employees.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'لا يوجد موظفون نشطون بعد.',
                    style: TextStyle(color: AppColors.statusRejected),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: employees.map((AppUser u) {
                      final selected = _selectedEmployeeUids.contains(u.uid);
                      return CheckboxListTile(
                        value: selected,
                        title: Text(u.name),
                        subtitle: Text(u.employeeNumber),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedEmployeeUids.add(u.uid);
                            } else {
                              _selectedEmployeeUids.remove(u.uid);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('إنشاء التصويت'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
