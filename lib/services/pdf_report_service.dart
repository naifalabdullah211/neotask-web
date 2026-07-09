import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';
import '../utils/recurrence_utils.dart';

/// Generates on-demand PDF task reports (manager-triggered only — not
/// automatic) covering the daily/weekly/monthly/individual-employee views.
class PdfReportService {
  static String _statusAr(TaskStatus s) {
    switch (s) {
      case TaskStatus.assigned:
        return 'مُسندة';
      case TaskStatus.inProgress:
        return 'قيد التنفيذ';
      case TaskStatus.submitted:
        return 'بانتظار المراجعة';
      case TaskStatus.approved:
        return 'مكتملة';
      case TaskStatus.rejected:
        return 'مرفوضة';
      case TaskStatus.editRequested:
        return 'مطلوب تعديل';
    }
  }

  static String _priorityAr(TaskPriority p) {
    switch (p) {
      case TaskPriority.low:
        return 'منخفضة';
      case TaskPriority.medium:
        return 'متوسطة';
      case TaskPriority.high:
        return 'عالية';
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  static Future<Uint8List> buildReport({
    required String title,
    required String rangeLabel,
    required List<AppTask> tasks,
    required Map<String, int> stats,
    Map<String, AppUser>? employeesById,
  }) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.notoSansArabicRegular();
    final boldFont = await PdfGoogleFonts.notoSansArabicBold();

    doc.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('NeoTask', style: const pw.TextStyle(fontSize: 22)),
                pw.SizedBox(height: 4),
                pw.Text(title, style: const pw.TextStyle(fontSize: 16)),
                pw.Text(rangeLabel, style: const pw.TextStyle(fontSize: 11)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _statBox('الإجمالي', stats['total'] ?? 0),
              _statBox('مكتملة', stats['approved'] ?? 0),
              _statBox('قيد الانتظار', stats['pending'] ?? 0),
              _statBox('بانتظار المراجعة', stats['submitted'] ?? 0),
              _statBox('مرفوضة', stats['rejected'] ?? 0),
              _statBox('متأخرة', stats['overdue'] ?? 0),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.6),
              3: const pw.FlexColumnWidth(1.6),
              4: const pw.FlexColumnWidth(1.6),
              5: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                children: [
                  _cell('العنوان', bold: true),
                  _cell('الموظف', bold: true),
                  _cell('الاستحقاق', bold: true),
                  _cell('الأولوية', bold: true),
                  _cell('الحالة', bold: true),
                  _cell('التكرار', bold: true),
                ],
              ),
              ...tasks.map(
                (t) => pw.TableRow(
                  children: [
                    _cell(t.title),
                    _cell(employeesById?[t.assignedTo]?.name ?? t.assignedTo),
                    _cell(_fmtDate(t.dueDate)),
                    _cell(_priorityAr(t.priority)),
                    _cell(_statusAr(t.status)),
                    _cell(RecurrenceUtils.recurrenceLabelAr(t)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'تم إنشاء هذا التقرير بواسطة المدير عبر منصة NeoTask بتاريخ ${_fmtDate(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _statBox(String label, int value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            '$value',
            style: const pw.TextStyle(fontSize: 14, color: PdfColors.blue900),
          ),
          pw.SizedBox(height: 2),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  static pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  /// Triggers the browser's native print/save-as-PDF dialog with the
  /// generated document — used for the on-demand export button.
  static Future<void> shareOrPrint(Uint8List bytes, String fileName) async {
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }
}
