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

/// Manager-only screen for creating a new "تصويت" (Poll) — UPGRADED
/// (Phase E) from the original binary Yes/No form into the full
/// multi-choice / multi-status creation form:
///   - title (required), long description (optional)
///   - optional image/PDF attachment (unchanged Cloudinary mechanism)
///   - DYNAMIC list of choices (minimum 2, pre-filled with the legacy
///     "نعم"/"لا" pair as a sensible default so existing manager habits
///     are preserved, but fully editable/extensible)
///   - OPTIONAL start date/time (defaults to "الآن" — i.e. creation time —
///     if left unset, exactly as [PollProvider.createPoll] already
///     defaults it)
///   - MANDATORY end date/time (unchanged requirement — a poll cannot be
///     saved without a deadline, enforced both here and at the provider/
///     model level)
///   - privacy toggle ("تفعيل خصوصية التصويت") — when ON, the manager's
///     live detail view will not reveal which employee picked which
///     choice (see ManagerPollDetailScreen); the permanent report NEVER
///     reveals per-employee choices regardless of this toggle (a
///     structural guarantee at the PollReport model level)
///   - explicit "حفظ كمسودة" vs "نشر الآن" choice (draft vs active),
///     replacing the old always-immediately-open behaviour
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
  final _employeeSearchCtrl = TextEditingController();
  String _employeeSearchQuery = '';

  // Dynamic choices list — pre-filled with the legacy Yes/No pair as a
  // convenient default; the manager can edit/add/remove freely (min 2
  // enforced in _save()).
  final List<TextEditingController> _choiceCtrls = [
    TextEditingController(text: 'نعم'),
    TextEditingController(text: 'لا'),
  ];

  // Start date/time is OPTIONAL — if left null, PollProvider.createPoll
  // defaults it to "now" at creation time. No default pre-fill here
  // (mirrors the deliberate "no silent default" pattern already used for
  // _deadline below) so the manager can explicitly choose a future start
  // if they want the poll to remain a draft-like "not yet started"
  // window, or simply leave it blank for "starts immediately".
  DateTime? _startDateTime;

  // No default deadline is pre-filled deliberately — an empty/null
  // deadline forces the manager to make an explicit choice, reinforcing
  // the "no poll without a deadline" requirement visually.
  DateTime? _deadline;

  bool _privacyEnabled = false;
  bool _saveAsDraft = false;

  String? _attachmentUrl;
  String? _attachmentName;
  String? _attachmentType; // 'image' | 'file'
  bool _uploadingAttachment = false;

  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _employeeSearchCtrl.dispose();
    for (final c in _choiceCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addChoiceField() {
    setState(() => _choiceCtrls.add(TextEditingController()));
  }

  void _removeChoiceField(int index) {
    if (_choiceCtrls.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب توفر اختيارين على الأقل')),
      );
      return;
    }
    setState(() {
      final removed = _choiceCtrls.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _pickStartDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDateTime ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _startDateTime != null
          ? TimeOfDay.fromDateTime(_startDateTime!)
          : TimeOfDay.fromDateTime(now),
    );
    if (pickedTime == null) return;
    setState(() {
      _startDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
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

    final choices = _choiceCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (choices.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب إدخال اختيارين على الأقل بنص غير فارغ'),
        ),
      );
      return;
    }
    final uniqueChoices = choices.toSet();
    if (uniqueChoices.length != choices.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن تكرار نفس الاختيار مرتين')),
      );
      return;
    }

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
    if (_startDateTime != null && _startDateTime!.isAfter(_deadline!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('موعد البدء يجب أن يكون قبل موعد الإغلاق'),
        ),
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
        choices: choices,
        startDateTime: _startDateTime,
        deadline: _deadline!,
        createdBy: managerUid,
        privacyEnabled: _privacyEnabled,
        asDraft: _saveAsDraft,
        attachmentUrl: _attachmentUrl,
        attachmentName: _attachmentName,
        attachmentType: _attachmentType,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _saveAsDraft
                ? 'تم حفظ التصويت كمسودة بنجاح'
                : 'تم إنشاء التصويت ونشره بنجاح',
          ),
        ),
      );
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
    final allEmployees = context.read<PollProvider>().getActiveEmployees();
    final query = _employeeSearchQuery.trim();
    final employees = query.isEmpty
        ? allEmployees
        : allEmployees.where((u) {
            final name = u.name.toLowerCase();
            final number = u.employeeNumber.toLowerCase();
            final q = query.toLowerCase();
            return name.contains(q) || number.contains(q);
          }).toList();

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

              // ---- choices (multi-choice, min 2) ----
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'اختيارات التصويت (اختياران على الأقل)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addChoiceField,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('إضافة اختيار'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...List.generate(_choiceCtrls.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _choiceCtrls[index],
                          decoration: InputDecoration(
                            labelText: 'اختيار ${index + 1}',
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: AppColors.statusRejected,
                        ),
                        onPressed: () => _removeChoiceField(index),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),

              // ---- privacy toggle ----
              Card(
                child: SwitchListTile(
                  value: _privacyEnabled,
                  onChanged: (v) => setState(() => _privacyEnabled = v),
                  title: const Text('تفعيل خصوصية التصويت'),
                  subtitle: const Text(
                    'عند التفعيل: لا يمكن معرفة اختيار موظف معيّن — فقط '
                    'حالة التصويت/عدم التصويت',
                    style: TextStyle(fontSize: 12),
                  ),
                  secondary: const Icon(
                    Icons.privacy_tip_outlined,
                    color: AppColors.deepBlue,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ---- optional start date/time ----
              const Text(
                'موعد بدء التصويت (اختياري — يبدأ فورًا إن لم يُحدَّد)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.play_circle_outline,
                    color: AppColors.deepBlue,
                  ),
                  title: Text(
                    _startDateTime == null
                        ? 'يبدأ فورًا عند النشر'
                        : intl.DateFormat(
                            'yyyy/MM/dd — HH:mm',
                          ).format(_startDateTime!),
                  ),
                  trailing: _startDateTime == null
                      ? const Icon(Icons.edit_calendar_outlined)
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setState(() => _startDateTime = null),
                        ),
                  onTap: _pickStartDateTime,
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

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'الموظفون المشاركون في التصويت',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_selectedEmployeeUids.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.deepBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'تم اختيار ${_selectedEmployeeUids.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.deepBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'يمكن اختيار أكثر من موظف واحد (الموظفون النشطون فقط)',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              if (allEmployees.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'لا يوجد موظفون نشطون بعد.',
                    style: TextStyle(color: AppColors.statusRejected),
                  ),
                )
              else ...[
                // Search field — lets the manager filter the (potentially
                // long) employee list by name or employee number instead
                // of having to scroll through every CheckboxListTile
                // looking for a specific person.
                TextField(
                  controller: _employeeSearchCtrl,
                  decoration: InputDecoration(
                    hintText: 'بحث عن موظف بالاسم أو الرقم الوظيفي...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _employeeSearchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _employeeSearchCtrl.clear();
                              setState(() => _employeeSearchQuery = '');
                            },
                          ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (v) => setState(() => _employeeSearchQuery = v),
                ),
                const SizedBox(height: 8),
                if (employees.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'لا يوجد موظف مطابق لعملية البحث.',
                      style: TextStyle(color: AppColors.textSecondary),
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
              ],
              const SizedBox(height: 20),

              // ---- draft vs publish ----
              const Text(
                'حالة الحفظ',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      value: false,
                      groupValue: _saveAsDraft,
                      onChanged: (v) => setState(() => _saveAsDraft = v!),
                      title: const Text('نشر الآن (يصبح نشطًا فورًا)'),
                    ),
                    RadioListTile<bool>(
                      value: true,
                      groupValue: _saveAsDraft,
                      onChanged: (v) => setState(() => _saveAsDraft = v!),
                      title: const Text('حفظ كمسودة (غير مرئي للموظفين)'),
                    ),
                  ],
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
                    : Text(_saveAsDraft ? 'حفظ كمسودة' : 'إنشاء ونشر التصويت'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
