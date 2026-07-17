import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/poll_model.dart';
import '../../models/user_model.dart';
import '../../providers/poll_provider.dart';
import '../../theme/app_theme.dart';

/// Manager-only screen for editing a draft-or-active poll — per the
/// explicit editing requirement: title/description/end-date-time/
/// eligible-employees/available-choices are all editable while active;
/// destructive changes (removing employees who already voted, changing
/// choices after votes exist) require confirmation; changing choices
/// after votes exist specifically requires an explicit "confirm to reset
/// votes" dialog (handled here via [PollProvider.hasAnyVotes] +
/// [PollProvider.updateActivePoll]'s `resetVotesIfChoicesChanged` flag).
/// No editing is possible once the poll is [PollStatus.ended] or
/// [PollStatus.cancelled] — this screen is never routed to for those
/// statuses (see ManagerPollDetailScreen, which only shows the edit
/// action for draft/active polls).
class EditPollScreen extends StatefulWidget {
  const EditPollScreen({super.key, required this.pollId});

  final String pollId;

  @override
  State<EditPollScreen> createState() => _EditPollScreenState();
}

class _EditPollScreenState extends State<EditPollScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  final List<TextEditingController> _choiceCtrls = [];
  final Set<String> _selectedEmployeeUids = {};
  final _employeeSearchCtrl = TextEditingController();
  String _employeeSearchQuery = '';

  DateTime? _startDateTime;
  DateTime? _deadline;
  bool _privacyEnabled = false;

  bool _initialized = false;
  bool _saving = false;

  List<String> _originalChoices = [];

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

  void _initFrom(AppPoll poll) {
    if (_initialized) return;
    _titleCtrl = TextEditingController(text: poll.title);
    _descCtrl = TextEditingController(text: poll.description);
    _choiceCtrls.addAll(
      poll.choices.map((c) => TextEditingController(text: c)),
    );
    _originalChoices = List.of(poll.choices);
    _selectedEmployeeUids.addAll(poll.participantUids);
    _startDateTime = poll.startDateTime;
    _deadline = poll.deadline;
    _privacyEnabled = poll.privacyEnabled;
    _initialized = true;
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
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startDateTime ?? now),
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
      initialTime: TimeOfDay.fromDateTime(_deadline ?? now),
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

  Future<void> _save(AppPoll poll) async {
    if (!_formKey.currentState!.validate()) return;

    final choices = _choiceCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (choices.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إدخال اختيارين على الأقل')),
      );
      return;
    }
    if (choices.toSet().length != choices.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن تكرار نفس الاختيار مرتين')),
      );
      return;
    }
    if (_deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تحديد موعد إغلاق التصويت')),
      );
      return;
    }
    if (_selectedEmployeeUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب اختيار موظف واحد على الأقل')),
      );
      return;
    }

    final choicesChanged = !_listEquals(choices, _originalChoices);
    var resetVotes = false;

    if (choicesChanged && poll.status == PollStatus.active) {
      final hasVotes = await context.read<PollProvider>().hasAnyVotes(
        poll.pollId,
      );
      if (hasVotes) {
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تأكيد تغيير الاختيارات'),
            content: const Text(
              'يوجد أصوات مسجّلة حاليًا على هذا التصويت. تغيير الاختيارات '
              'سيؤدي إلى حذف جميع الأصوات الحالية بشكل نهائي. هل تريد '
              'المتابعة؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('تراجع'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.statusRejected,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('نعم، حذف الأصوات والمتابعة'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        resetVotes = true;
      }
    }

    // Destructive-change confirmation: removing an employee who already
    // voted.
    final removedEmployees = _originalParticipantsRemoved(poll);
    if (removedEmployees.isNotEmpty) {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تأكيد إزالة موظفين'),
          content: Text(
            'تتم إزالة ${removedEmployees.length} موظف من قائمة المشاركين. '
            'هل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('تراجع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await context.read<PollProvider>().updateActivePoll(
        pollId: poll.pollId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        choices: choices,
        participantUids: _selectedEmployeeUids.toList(),
        startDateTime: _startDateTime,
        deadline: _deadline,
        privacyEnabled: _privacyEnabled,
        resetVotesIfChoicesChanged: resetVotes,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات بنجاح')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذّر حفظ التعديلات: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _originalParticipantsRemoved(AppPoll poll) {
    return poll.participantUids
        .where((uid) => !_selectedEmployeeUids.contains(uid))
        .toList();
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final poll = context.watch<PollProvider>().getPoll(widget.pollId);
    if (poll == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تعديل التصويت')),
        body: const Center(child: Text('التصويت غير متاح')),
      );
    }
    _initFrom(poll);

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
      appBar: AppBar(title: const Text('تعديل التصويت')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'العنوان'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'أدخل العنوان' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'الوصف'),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'اختيارات التصويت',
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

              Card(
                child: SwitchListTile(
                  value: _privacyEnabled,
                  onChanged: (v) => setState(() => _privacyEnabled = v),
                  title: const Text('تفعيل خصوصية التصويت'),
                  secondary: const Icon(
                    Icons.privacy_tip_outlined,
                    color: AppColors.deepBlue,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'موعد البدء',
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
                        ? 'غير محدد'
                        : intl.DateFormat(
                            'yyyy/MM/dd — HH:mm',
                          ).format(_startDateTime!),
                  ),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: _pickStartDateTime,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'موعد الإغلاق (مطلوب)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.event_busy_outlined,
                    color: AppColors.deepBlue,
                  ),
                  title: Text(
                    _deadline == null
                        ? 'غير محدد'
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
                      'الموظفون المشاركون',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
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
                      '${_selectedEmployeeUids.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.deepBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _employeeSearchCtrl,
                decoration: InputDecoration(
                  hintText: 'بحث عن موظف...',
                  prefixIcon: const Icon(Icons.search),
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
                onPressed: _saving ? null : () => _save(poll),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('حفظ التعديلات'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
