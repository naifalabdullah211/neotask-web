import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/meeting_model.dart';
import '../../models/user_model.dart';
import '../../providers/meeting_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

/// Meeting scheduling ("الاجتماعات") — visible to both manager and
/// employee. This is a scheduling record ONLY: title, time, location,
/// participants. There is no live audio/video call integration; joining a
/// meeting happens outside the app (in person, phone, or a link pasted
/// into the location field).
class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({
    super.key,
    required this.currentUserUid,
    required this.currentUserName,
    required this.isManager,
  });

  final String currentUserUid;
  final String currentUserName;
  final bool isManager;

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  bool _showPast = false;

  Future<void> _createMeeting() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    DateTime date = DateTime.now().add(const Duration(hours: 1));
    TimeOfDay time = TimeOfDay.fromDateTime(date);
    final selectedParticipants = <String>{};

    final employees = FirestoreService.getAllEmployees()
        .where((e) => e.accountStatus == AccountStatus.active)
        .toList();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('اجتماع جديد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'عنوان الاجتماع'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'الوصف (اختياري)'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'المكان / رابط الاتصال',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(intl.DateFormat('yyyy/MM/dd').format(date)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          date = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time_outlined),
                    title: Text(time.format(context)),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: time,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          time = picked;
                          date = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            picked.hour,
                            picked.minute,
                          );
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  if (employees.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'المشاركون',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      children: employees.map((e) {
                        final selected = selectedParticipants.contains(e.uid);
                        return FilterChip(
                          label: Text(e.name),
                          selected: selected,
                          onSelected: (v) {
                            setDialogState(() {
                              if (v) {
                                selectedParticipants.add(e.uid);
                              } else {
                                selectedParticipants.remove(e.uid);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  if (titleCtrl.text.trim().isEmpty) return;
                  Navigator.pop(context, true);
                },
                child: const Text('إنشاء'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && mounted) {
      await context.read<MeetingProvider>().createMeeting(
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
        startTime: date,
        location: locationCtrl.text.trim(),
        createdBy: widget.currentUserUid,
        createdByName: widget.currentUserName,
        participantUids: selectedParticipants.toList(),
      );
    }
  }

  Future<void> _confirmDelete(MeetingItem meeting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الاجتماع'),
        content: Text('هل تريد حذف "${meeting.title}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusRejected,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<MeetingProvider>().deleteMeeting(meeting.meetingId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MeetingProvider>();
    final list = _showPast ? provider.past : provider.upcoming;

    return Scaffold(
      appBar: AppBar(title: const Text('الاجتماعات')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('القادمة')),
                  ButtonSegment(value: true, label: Text('السابقة')),
                ],
                selected: {_showPast},
                onSelectionChanged: (s) => setState(() => _showPast = s.first),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        _showPast
                            ? 'لا توجد اجتماعات سابقة'
                            : 'لا توجد اجتماعات قادمة',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final m = list[index];
                        final canDelete =
                            m.createdBy == widget.currentUserUid ||
                            widget.isManager;
                        return Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.groups_outlined,
                              color: AppColors.deepBlue,
                            ),
                            title: Text(
                              m.title,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  intl.DateFormat(
                                    'yyyy/MM/dd HH:mm',
                                  ).format(m.startTime),
                                ),
                                if (m.location.isNotEmpty)
                                  Text('المكان: ${m.location}'),
                                Text('بواسطة: ${m.createdByName}'),
                              ],
                            ),
                            isThreeLine: m.location.isNotEmpty,
                            trailing: canDelete
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: AppColors.statusRejected,
                                    ),
                                    onPressed: () => _confirmDelete(m),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createMeeting,
        child: const Icon(Icons.add),
      ),
    );
  }
}
