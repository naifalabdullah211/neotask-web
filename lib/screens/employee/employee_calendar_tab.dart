import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../providers/calendar_provider.dart';
import '../../theme/app_theme.dart';

/// Read-only iPhone Calendar (.ics feed) import screen.
/// Sync happens automatically once on page load (per project decision),
/// plus a manual "Sync now" button. Direction is strictly one-way:
/// iPhone Calendar -> App (never App -> Calendar).
class EmployeeCalendarTab extends StatefulWidget {
  final String employeeUid;
  const EmployeeCalendarTab({super.key, required this.employeeUid});

  @override
  State<EmployeeCalendarTab> createState() => _EmployeeCalendarTabState();
}

class _EmployeeCalendarTabState extends State<EmployeeCalendarTab> {
  final _urlCtrl = TextEditingController();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<CalendarProvider>();
      await provider.loadIcsUrlForUser(widget.employeeUid);
      if (provider.savedIcsUrl != null) {
        _urlCtrl.text = provider.savedIcsUrl!;
      }
      if (mounted) setState(() => _initialized = true);
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndSync() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    final provider = context.read<CalendarProvider>();
    await provider.saveIcsUrl(widget.employeeUid, url);
    await provider.syncNow(widget.employeeUid, url);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CalendarProvider>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined,
                          color: AppColors.deepBlue),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('استيراد تقويم الآيفون (قراءة فقط)',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'ألصق رابط الاشتراك (.ics) من تطبيق تقويم الآيفون. تتم المزامنة تلقائيًا عند فتح الصفحة، بالإضافة لإمكانية المزامنة اليدوية. الاتجاه: من تقويم الآيفون إلى هذا التطبيق فقط.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'رابط ICS / Webcal',
                      hintText: 'webcal://p123-caldav.icloud.com/...',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: provider.isLoading ? null : _saveAndSync,
                      icon: provider.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.sync),
                      label: Text(provider.isLoading
                          ? 'جارٍ المزامنة...'
                          : 'حفظ ومزامنة الآن'),
                    ),
                  ),
                  if (provider.error != null) ...[
                    const SizedBox(height: 8),
                    Text(provider.error!,
                        style: const TextStyle(
                            color: AppColors.statusRejected, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('أحداث الشهر الحالي (${provider.events.length})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (!_initialized)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (provider.events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('لا توجد أحداث مستوردة بعد',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ...provider.events.map((e) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_note_outlined,
                        color: AppColors.lightBlue),
                    title: Text(e.summary),
                    subtitle: Text(
                      e.end != null
                          ? '${intl.DateFormat('yyyy/MM/dd HH:mm').format(e.start)} - ${intl.DateFormat('HH:mm').format(e.end!)}'
                          : intl.DateFormat('yyyy/MM/dd HH:mm').format(e.start),
                    ),
                    trailing: e.isRecurringInstance
                        ? const Icon(Icons.repeat, size: 16)
                        : null,
                  ),
                )),
        ],
      ),
    );
  }
}
