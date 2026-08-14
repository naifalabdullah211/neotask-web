import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/workflow_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/import_table_parser.dart';
import '../../widgets/neo_selection_field.dart';
import '../../widgets/neo_workspace_chrome.dart';

enum _ImportType { employees, tasks }

class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({super.key, this.readOnly = false});
  final bool readOnly;

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  _ImportType _type = _ImportType.employees;
  String? _fileName;
  ImportedTable? _table;
  List<_ValidatedRow> _preview = const [];
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final validCount = _preview.where((row) => row.errors.isEmpty).length;
    final errorCount = _preview.length - validCount;
    final totalCount = _preview.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'استيراد Excel / CSV',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_table != null)
              NeoWorkspaceMetricsBar(
                items: [
                  NeoWorkspaceMetric(
                    label: 'إجمالي الصفوف',
                    value: '$totalCount',
                    icon: Icons.table_rows_outlined,
                    color: AppColors.deepBlue,
                  ),
                  NeoWorkspaceMetric(
                    label: 'صفوف صالحة',
                    value: '$validCount',
                    icon: Icons.check_circle_outline,
                    color: AppColors.statusApproved,
                  ),
                  NeoWorkspaceMetric(
                    label: 'صفوف بها أخطاء',
                    value: '$errorCount',
                    icon: Icons.error_outline_rounded,
                    color: AppColors.statusRejected,
                  ),
                ],
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.upload_file_outlined,
                          color: AppColors.goldLight,
                          size: 38,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'استيراد حقيقي مع فحص قبل الحفظ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'لن يُحفظ أي صف خاطئ أو مكرر، وسترى نتيجة كل صف أولًا',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const NeoWorkspaceSectionHeader(
                          title: 'إعداد الاستيراد',
                          subtitle:
                              'اختر نوع البيانات وارفع الملف ثم راجع النتيجة قبل الحفظ',
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              NeoSelectionField<_ImportType>(
                                label: 'نوع البيانات',
                                value: _type,
                                enabled: !widget.readOnly,
                                options: const [
                                  NeoSelectionOption(
                                    value: _ImportType.employees,
                                    label: 'الموظفون',
                                    icon: Icons.groups_outlined,
                                  ),
                                  NeoSelectionOption(
                                    value: _ImportType.tasks,
                                    label: 'المهام',
                                    icon: Icons.task_alt_outlined,
                                  ),
                                ],
                                onChanged: widget.readOnly
                                    ? null
                                    : (value) => setState(() {
                                        _type = value;
                                        _fileName = null;
                                        _table = null;
                                        _preview = const [];
                                      }),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _TemplateCard(type: _type),
                              if (!widget.readOnly) ...[
                                const SizedBox(height: AppSpacing.md),
                                OutlinedButton.icon(
                                  onPressed: _busy ? null : _pickFile,
                                  icon: const Icon(Icons.attach_file_rounded),
                                  label: Text(
                                    _fileName == null
                                        ? 'اختيار ملف CSV أو XLSX'
                                        : '${context.tr('الملف')}: $_fileName',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_table == null)
                    SizedBox(
                      height: 250,
                      child: NeoWorkspaceEmptyState(
                        icon: Icons.table_view_outlined,
                        title: _fileName == null
                            ? 'لم يتم اختيار ملف بعد'
                            : 'ملف جاهز للمراجعة',
                        message:
                            'اختر ملف CSV أو XLSX لبدء المعاينة والتحقق قبل الحفظ.',
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const NeoWorkspaceSectionHeader(
                            title: 'مراجعة البيانات',
                            subtitle:
                                'راجع الصفوف الصالحة والأخطاء قبل تنفيذ الاستيراد',
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              children: [
                                for (final entry in _preview.asMap().entries)
                                  _PreviewRowCard(
                                    index: entry.key,
                                    row: entry.value,
                                    type: _type,
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              0,
                              AppSpacing.lg,
                              AppSpacing.lg,
                            ),
                            child: FilledButton.icon(
                              onPressed: _busy || validCount == 0
                                  ? null
                                  : _importValidRows,
                              icon: _busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.cloud_upload_outlined),
                              label: Text('استيراد $validCount صف صالح'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
      withData: true,
    );
    if (result == null) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _show('تعذّر قراءة الملف');
      return;
    }
    try {
      final table = ImportTableParser.parse(
        fileName: file.name,
        bytes: Uint8List.fromList(bytes),
      );
      final preview = _type == _ImportType.employees
          ? _validateEmployees(table)
          : _validateTasks(table);
      setState(() {
        _fileName = file.name;
        _table = table;
        _preview = preview;
      });
    } on FormatException catch (error) {
      _show(error.message);
    } catch (_) {
      _show('صيغة الملف غير صالحة أو الملف تالف');
    }
  }

  List<_ValidatedRow> _validateEmployees(ImportedTable table) {
    const required = {'name', 'employeeNumber', 'password'};
    final missing = required.difference(table.headers.toSet());
    if (missing.isNotEmpty)
      throw FormatException(
        'الأعمدة المطلوبة: الاسم، الرقم الوظيفي، كلمة المرور',
      );
    final existing = FirestoreService.getAllEmployees()
        .map((user) => _compact(user.employeeNumber))
        .toSet();
    final seen = <String>{};
    return table.rows.map((row) {
      final errors = <String>[];
      final number = _compact(row['employeeNumber'] ?? '');
      if ((row['name'] ?? '').trim().isEmpty) errors.add('الاسم مفقود');
      if (number.isEmpty) errors.add('الرقم الوظيفي مفقود');
      if ((row['password'] ?? '').length < 6)
        errors.add('كلمة المرور أقل من 6 أحرف');
      if (existing.contains(number)) errors.add('الرقم الوظيفي موجود مسبقًا');
      if (!seen.add(number)) errors.add('الرقم الوظيفي مكرر داخل الملف');
      return _ValidatedRow(data: row, errors: errors);
    }).toList();
  }

  List<_ValidatedRow> _validateTasks(ImportedTable table) {
    const required = {'title', 'employeeNumber', 'dueDate'};
    if (!required.every(table.headers.contains))
      throw FormatException(
        'الأعمدة المطلوبة: عنوان المهمة، الرقم الوظيفي، تاريخ الاستحقاق',
      );
    final employees = {
      for (final user in FirestoreService.getAllEmployees().where(
        (u) => u.accountStatus == AccountStatus.active,
      ))
        _compact(user.employeeNumber): user,
    };
    String duplicateKey(String title, String employeeUid, DateTime due) =>
        '${title.trim().toLowerCase()}|$employeeUid|${due.year}-${due.month}-${due.day}';
    final existing = FirestoreService.getAllTasks()
        .map((task) => duplicateKey(task.title, task.assignedTo, task.dueDate))
        .toSet();
    final seen = <String>{};
    return table.rows.map((row) {
      final errors = <String>[];
      if ((row['title'] ?? '').trim().isEmpty) errors.add('عنوان المهمة مفقود');
      final employee = employees[_compact(row['employeeNumber'] ?? '')];
      if (employee == null) errors.add('الموظف غير موجود أو غير نشط');
      final due = _parseDate(row['dueDate'] ?? '');
      if (due == null) errors.add('تاريخ الاستحقاق غير صالح');
      final current = DateTime.now();
      final start = (row['startDate'] ?? '').trim().isEmpty
          ? DateTime(current.year, current.month, current.day)
          : _parseDate(row['startDate']!);
      if (start == null) errors.add('تاريخ البداية غير صالح');
      if (start != null && due != null && due.isBefore(start))
        errors.add('الاستحقاق يسبق البداية');
      final hours = (row['plannedHours'] ?? '').trim().isEmpty
          ? 1
          : double.tryParse(row['plannedHours']!);
      if (hours == null || hours <= 0) errors.add('الساعات غير صالحة');
      if (_parsePriority(row['priority'] ?? '') == null)
        errors.add('الأولوية غير صالحة');
      if (employee != null &&
          due != null &&
          (row['title'] ?? '').trim().isNotEmpty) {
        final key = duplicateKey(row['title']!, employee.uid, due);
        if (existing.contains(key)) errors.add('المهمة موجودة مسبقًا');
        if (!seen.add(key)) errors.add('المهمة مكررة داخل الملف');
      }
      return _ValidatedRow(data: row, errors: errors);
    }).toList();
  }

  Future<void> _importValidRows() async {
    setState(() => _busy = true);
    final valid = _preview.where((row) => row.errors.isEmpty).toList();
    try {
      if (_type == _ImportType.employees) {
        final result = await WorkflowService.importEmployees(
          valid
              .map(
                (row) => {
                  'name': row.data['name']!.trim(),
                  'employeeNumber': row.data['employeeNumber']!.trim(),
                  'password': row.data['password']!,
                },
              )
              .toList(),
        );
        final created = result['createdCount'] ?? 0;
        final failed = result['failedCount'] ?? 0;
        _show(
          'تم إنشاء $created حساب موظف${failed == 0 ? '' : '، وتعذر $failed'}',
        );
      } else {
        final managerUid = context.read<AuthProvider>().currentUser!.uid;
        final employees = {
          for (final user in FirestoreService.getAllEmployees())
            _compact(user.employeeNumber): user,
        };
        final now = DateTime.now();
        final tasks = valid.map((row) {
          final due = _parseDate(row.data['dueDate']!)!;
          final rawStart = row.data['startDate'] ?? '';
          final start = rawStart.trim().isEmpty
              ? DateTime(now.year, now.month, now.day)
              : _parseDate(rawStart)!;
          return AppTask(
            taskId: const Uuid().v4(),
            title: row.data['title']!.trim(),
            description: (row.data['description'] ?? '').trim(),
            assignedTo: employees[_compact(row.data['employeeNumber']!)]!.uid,
            assignedBy: managerUid,
            dueDate: due,
            startDate: start,
            plannedHours: double.tryParse(row.data['plannedHours'] ?? '') ?? 1,
            priority: _parsePriority(row.data['priority'] ?? '')!,
            status: TaskStatus.assigned,
            category: (row.data['category'] ?? '').trim().isEmpty
                ? 'عام'
                : row.data['category']!.trim(),
            createdAt: now,
            updatedAt: now,
          );
        }).toList();
        await WorkflowService.importTasks(
          tasks: tasks,
          managerUid: managerUid,
          sourceFileName: _fileName!,
        );
        _show('تم إنشاء ${tasks.length} مهمة بنجاح');
      }
      if (mounted)
        setState(() {
          _fileName = null;
          _table = null;
          _preview = const [];
        });
    } catch (error) {
      _show(
        'تعذر الاستيراد: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr(message))));
    }
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.type});

  final _ImportType type;

  @override
  Widget build(BuildContext context) {
    final columns = type == _ImportType.employees
        ? 'الاسم | الرقم الوظيفي | كلمة المرور'
        : 'عنوان المهمة | الرقم الوظيفي | تاريخ الاستحقاق | الوصف | تاريخ البداية | الساعات | الأولوية | التصنيف';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.deepBlue.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.view_column_outlined,
              color: AppColors.deepBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('عناوين الصف الأول', style: AppTextStyles.cardTitle),
                const SizedBox(height: 6),
                SelectableText(
                  context.tr(columns),
                  textDirection: Directionality.of(context),
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 5),
                const Text(
                  'تُقبل العناوين العربية أو الإنجليزية، والتاريخ بصيغة YYYY-MM-DD',
                  style: AppTextStyles.bodySecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRowCard extends StatelessWidget {
  const _PreviewRowCard({
    required this.index,
    required this.row,
    required this.type,
  });

  final int index;
  final _ValidatedRow row;
  final _ImportType type;

  @override
  Widget build(BuildContext context) {
    final ok = row.errors.isEmpty;
    final title = type == _ImportType.employees
        ? row.data['name']
        : row.data['title'];
    final displayTitle = title == null || title.isEmpty
        ? context.tr('صف بلا عنوان')
        : title;
    final accent = ok ? AppColors.statusApproved : AppColors.statusRejected;
    final details = ok
        ? context.tr('صالح للاستيراد')
        : row.errors.map(context.tr).join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accent.withValues(alpha: .28)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              ok ? Icons.check_rounded : Icons.close_rounded,
              color: accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 2}. $displayTitle',
                  style: AppTextStyles.cardTitle,
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: ok
                        ? AppColors.textSecondary
                        : AppColors.statusRejected,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            row.data['employeeNumber'] ?? '',
            style: AppTextStyles.bodySecondary.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidatedRow {
  const _ValidatedRow({required this.data, required this.errors});
  final Map<String, String> data;
  final List<String> errors;
}

String _compact(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

TaskPriority? _parsePriority(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty ||
      normalized == 'medium' ||
      normalized == 'متوسطة' ||
      normalized == 'متوسطه')
    return TaskPriority.medium;
  if (normalized == 'low' || normalized == 'منخفضة' || normalized == 'منخفضه')
    return TaskPriority.low;
  if (normalized == 'high' || normalized == 'عالية' || normalized == 'عاليه')
    return TaskPriority.high;
  return null;
}

DateTime? _parseDate(String value) {
  final trimmed = value.trim();
  final direct = DateTime.tryParse(trimmed);
  if (direct != null) {
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(trimmed);
    if (iso == null ||
        (direct.year == int.parse(iso.group(1)!) &&
            direct.month == int.parse(iso.group(2)!) &&
            direct.day == int.parse(iso.group(3)!))) {
      return direct;
    }
    return null;
  }
  final parts = trimmed.split(RegExp(r'[/\-.]'));
  if (parts.length != 3) return null;
  final a = int.tryParse(parts[0]);
  final b = int.tryParse(parts[1]);
  final c = int.tryParse(parts[2]);
  if (a == null || b == null || c == null) return null;
  try {
    final year = a > 1900 ? a : c;
    final month = b;
    final day = a > 1900 ? c : a;
    final parsed = DateTime(year, month, day);
    return parsed.year == year && parsed.month == month && parsed.day == day
        ? parsed
        : null;
  } catch (_) {
    return null;
  }
}
